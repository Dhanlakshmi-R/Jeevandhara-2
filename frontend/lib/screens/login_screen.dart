import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/locale.dart';
import '../widgets/auth_layout.dart';
import '../widgets/agri_scene.dart';
import '../widgets/ui/app_input.dart';
import '../widgets/ui/buttons.dart';
import 'about_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'trader_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();

  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      final role = await _apiService.getSavedRole();
      final next = (role != null && role != 'farmer')
          ? const TraderDashboardScreen()
          : const HomeScreen();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon')),
    );
  }

  void _phoneLogin() {
    final phoneController = TextEditingController();
    final otpController = TextEditingController();
    var step = 0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
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
                  step == 0 ? 'Login with Phone' : 'Enter OTP',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step == 0
                      ? 'We\'ll send a one-time password to verify your number.'
                      : 'We sent a 4-digit code to ******${phoneController.text.isEmpty ? '0000' : phoneController.text.substring(phoneController.text.length > 4 ? phoneController.text.length - 4 : 0)}.',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: step == 0 ? phoneController : otpController,
                  label: step == 0 ? 'Mobile number' : 'OTP',
                  icon: step == 0 ? Icons.phone_iphone : Icons.pin_outlined,
                  hint: step == 0 ? '98765 43210' : '1234',
                  keyboardType:
                      step == 0 ? TextInputType.phone : TextInputType.number,
                  textInputAction: TextInputAction.done,
                ),
                if (step == 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: c.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          context.str(K.demoOtp),
                          style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                AppPrimaryButton(
                  label: step == 0 ? 'Send OTP' : 'Verify & Login',
                  icon: step == 0 ? Icons.send_outlined : Icons.check_circle_outline,
                  height: 52,
                  onPressed: () {
                    if (step == 0) {
                      if (phoneController.text.trim().length != 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a valid 10-digit mobile number')),
                        );
                        return;
                      }
                      setSheetState(() => step = 1);
                    } else {
                      if (otpController.text.trim() != '1234') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Incorrect OTP. Demo OTP is 1234')),
                        );
                        return;
                      }
                      Navigator.of(sheetContext).pop();
                      _completeDemoLogin('Phone (OTP)');
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _googleLogin() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF223127)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: Color(0xFF1F6B45)),
              SizedBox(height: 14),
              Text('Connecting to Google\u2026'),
            ],
          ),
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.of(context).pop();
    _completeDemoLogin('Google');
  }

  Future<void> _completeDemoLogin(String method) async {
    await ApiService().saveUserRole('farmer');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Signed in with $method (demo)')),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      headline: 'Welcome back',
      subhead: 'Log in to continue farming smarter.',
      scene: AgriSceneKind.sunrise,
      child: _buildForm(),
    );
  }

  Widget _buildForm() {
    final c = context.colors;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (v) => (v == null || v.length < 6)
                ? 'Minimum 6 characters'
                : null,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                activeColor: c.primary,
                onChanged: (v) => setState(() => _rememberMe = v ?? true),
              ),
              Text('Remember me', style: TextStyle(color: c.textPrimary, fontSize: 14)),
              const Spacer(),
              TextButton(
                onPressed: () => _comingSoon('Forgot password'),
                child: const Text('Forgot password?'),
              ),
            ],
          ),
          if (_errorMessage != null) _errorBanner(c, _errorMessage!),
          AppPrimaryButton(
            label: 'Login',
            icon: Icons.login,
            loading: _isLoading,
            onPressed: _handleLogin,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Divider(color: c.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or continue with',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ),
              Expanded(child: Divider(color: c.divider)),
            ],
          ),
          const SizedBox(height: 14),
          _SocialButton(
            icon: Icons.phone_iphone,
            label: 'Login with Phone (OTP)',
            onTap: _phoneLogin,
          ),
          const SizedBox(height: 12),
          _SocialButton(
            icon: Icons.g_mobiledata,
            label: 'Continue with Google',
            onTap: _googleLogin,
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(color: c.textSecondary, fontSize: 14),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: Text(
                  'Register',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Discover Jeevandhara\'s story  ',
                style: TextStyle(color: c.textSecondary, fontSize: 12.5),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                },
                child: Text(
                  'About our project',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: c.primary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(ThemeColors c, String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.dangerSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: c.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: c.danger, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        icon: Icon(icon, color: c.primary, size: 20),
        label: Text(label),
      ),
    );
  }
}