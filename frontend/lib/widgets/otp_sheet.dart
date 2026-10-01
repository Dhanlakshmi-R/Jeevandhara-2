import 'dart:async';

import 'package:flutter/material.dart';

import 'package:jeevandhara2/models/auth_result.dart';
import 'package:jeevandhara2/services/api_service.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/widgets/ui/buttons.dart';

/// Shows the phone-OTP bottom sheet and returns the [AuthResult] when the
/// OTP is verified, or `null` if the user cancels.
Future<AuthResult?> showOtpLoginSheet(BuildContext context) {
  return showModalBottomSheet<AuthResult?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _OtpSheetBody(),
  );
}

class _OtpSheetBody extends StatefulWidget {
  const _OtpSheetBody();

  @override
  State<_OtpSheetBody> createState() => _OtpSheetBodyState();
}

class _OtpSheetBodyState extends State<_OtpSheetBody> {
  final _apiService = ApiService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();

  int _step = 0; // 0 = enter phone, 1 = enter OTP
  bool _loading = false;
  String? _error;
  String _maskedPhone = '';
  int _resendAfter = 30; // seconds until Resend is enabled
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _phoneFocus.requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────
  //  Phone number helpers
  // ──────────────────────────────────────────────────────────────────

  String get _rawDigits {
    final text = _phoneController.text.replaceAll(RegExp(r'[\s\-()]'), '');
    return text;
  }

  bool get _isValidPhone => RegExp(r'^[6-9]\d{9}$').hasMatch(_rawDigits);

  String _maskPhone(String digits) {
    if (digits.length < 4) return '****';
    return '******${digits.substring(digits.length - 4)}';
  }

  // ──────────────────────────────────────────────────────────────────
  //  Send OTP
  // ──────────────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    if (!_isValidPhone) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final seconds = await _apiService.sendOtp(_rawDigits);
      _maskedPhone = _maskPhone(_rawDigits);
      if (!mounted) return;
      setState(() {
        _step = 1;
        _loading = false;
      });
      _startResendTimer(seconds);
      _otpFocus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ──────────────────────────────────────────────────────────────────
  //  Verify OTP
  // ──────────────────────────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4 || otp.length > 8) {
      setState(() => _error = 'Enter the complete code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _apiService.verifyOtp(_rawDigits, otp);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ──────────────────────────────────────────────────────────────────
  //  Resend timer
  // ──────────────────────────────────────────────────────────────────

  void _startResendTimer(int seconds) {
    _timer?.cancel();
    setState(() => _resendAfter = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendAfter <= 1) {
        t.cancel();
        setState(() => _resendAfter = 0);
      } else {
        setState(() => _resendAfter--);
      }
    });
  }

  Future<void> _resend() async {
    _otpController.clear();
    await _sendOtp();
  }

  // ──────────────────────────────────────────────────────────────────
  //  Change number
  // ──────────────────────────────────────────────────────────────────

  void _changeNumber() {
    _timer?.cancel();
    _otpController.clear();
    setState(() {
      _step = 0;
      _error = null;
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _phoneFocus.requestFocus());
  }

  // ──────────────────────────────────────────────────────────────────
  //  UI
  // ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark
        ? ThemeColors.dark
        : ThemeColors.light;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _step == 0 ? 'Login with Phone' : 'Enter OTP',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            _step == 0
                ? "We'll send a one-time password to verify your number."
                : 'We sent a 6-digit code to $_maskedPhone.',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          _buildInput(c),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: c.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                          fontSize: 13,
                          color: c.danger,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          AppPrimaryButton(
            label: _step == 0 ? 'Send OTP' : 'Verify & Login',
            icon: _step == 0 ? Icons.send_outlined : Icons.check_circle_outline,
            loading: _loading,
            onPressed: _step == 0 ? _sendOtp : _verifyOtp,
          ),
          if (_step == 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _resendAfter > 0 ? null : _resend,
                      child: Text(
                        _resendAfter > 0
                            ? 'Resend in $_resendAfter s'
                            : 'Resend code',
                        style: TextStyle(
                          fontSize: 13,
                          color: _resendAfter > 0 ? c.textSecondary : c.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: _loading ? null : _changeNumber,
                      child: Text(
                        'Change number',
                        style: TextStyle(
                          fontSize: 13,
                          color: c.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInput(ThemeColors c) {
    if (_step == 0) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed +91 prefix
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag_outlined, size: 18, color: c.textSecondary),
                const SizedBox(width: 6),
                Text('+91',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _phoneController,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              maxLength: 10,
              style: TextStyle(color: c.textPrimary, fontSize: 15),
              cursorColor: c.primary,
              onSubmitted: (_) {
                if (_isValidPhone && !_loading) _sendOtp();
              },
              key: const ValueKey('phone_input'),
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                hintText: '98765 43210',
                prefixIcon: Icon(Icons.phone_iphone),
                counterText: '',
              ),
            ),
          ),
        ],
      );
    }
    // Step 1: OTP
    return TextField(
      controller: _otpController,
      focusNode: _otpFocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      maxLength: 6,
      style: TextStyle(
        fontSize: 20,
        letterSpacing: 6,
        fontWeight: FontWeight.w700,
        color: c.textPrimary,
      ),
      cursorColor: c.primary,
      onSubmitted: (_) {
        if (_otpController.text.trim().length >= 4 && !_loading) _verifyOtp();
      },
      decoration: const InputDecoration(
        labelText: 'One-time code',
        prefixIcon: Icon(Icons.pin_outlined),
        counterText: '',
      ),
    );
  }
}
