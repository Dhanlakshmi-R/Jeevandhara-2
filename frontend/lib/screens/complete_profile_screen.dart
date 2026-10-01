import 'package:flutter/material.dart';

import 'package:jeevandhara2/models/user.dart';
import 'package:jeevandhara2/services/api_service.dart';
import 'package:jeevandhara2/services/auth_navigation.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/widgets/ui/app_input.dart';
import 'package:jeevandhara2/widgets/ui/buttons.dart';

/// Shown right after a Google/OTP sign-in for accounts where the backend
/// returned `profile_complete=false`. Collects the missing details (name,
/// role, location) before entering the app.
class CompleteProfileScreen extends StatefulWidget {
  final AppUser? user;

  const CompleteProfileScreen({super.key, this.user});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _apiService = ApiService();

  static const _states = [
    'Karnataka',
    'Maharashtra',
    'Tamil Nadu',
    'Andhra Pradesh',
    'Telangana',
    'Gujarat',
    'Punjab',
    'Madhya Pradesh',
    'Rajasthan',
    'Uttar Pradesh',
  ];

  static const _districts = [
    'Belagavi',
    'Ballari',
    'Dharwad',
    'Gadag',
    'Haveri',
    'Kolar',
    'Mysuru',
    'Raichur',
    'Tumakuru',
    'Udupi',
    'Nagpur',
    'Amravati',
    'Pune',
  ];

  String _role = 'farmer';
  String? _state;
  String? _district;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _phoneLocked =>
      widget.user?.phone != null && widget.user?.phoneVerified == true;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameController.text = user?.name ?? '';
    if (_phoneLocked && user?.phone != null) {
      _phoneController.text = user!.phone!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final location = [_district, _state].whereType<String>().join(', ');
      final result = await _apiService.completeProfile(
        name: _nameController.text.trim(),
        role: _role,
        phone: _phoneController.text.trim(),
        location: location.isEmpty ? null : location,
      );
      if (!mounted) return;
      navigateAfterAuth(context, result.user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Complete your profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Just a few details to set up your Jeevandhara account.',
                  style: TextStyle(fontSize: 14, color: c.textSecondary),
                ),
                const SizedBox(height: 20),
                Text(
                  'I am a',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                      fontSize: 14.5),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _RoleCard(
                      label: 'Farmer',
                      icon: Icons.agriculture_outlined,
                      emoji: '\uD83D\uDC33',
                      selected: _role == 'farmer',
                      onTap: () => setState(() => _role = 'farmer'),
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _RoleCard(
                      label: 'Trader',
                      icon: Icons.storefront_outlined,
                      emoji: '\uD83E\uDDD1\u200D\uD83D\uDCBC',
                      selected: _role == 'trader',
                      onTap: () => setState(() => _role = 'trader'),
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _RoleCard(
                      label: 'Vendor',
                      icon: Icons.shopping_bag_outlined,
                      emoji: '\uD83D\uDED2',
                      selected: _role == 'vendor',
                      onTap: () => setState(() => _role = 'vendor'),
                    )),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _nameController,
                  label: 'Full name',
                  icon: Icons.person_outline,
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter your full name'
                      : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _phoneController,
                  label: _phoneLocked
                      ? 'Verified mobile number'
                      : 'Mobile number (optional)',
                  icon: Icons.phone_android,
                  keyboardType: TextInputType.phone,
                  enabled: !_phoneLocked,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())
                        ? null
                        : 'Enter a valid 10-digit number';
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppDropdownField(
                        label: 'State',
                        icon: Icons.map_outlined,
                        value: _state,
                        items: _states,
                        onChanged: (v) => setState(() => _state = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppDropdownField(
                        label: 'District',
                        icon: Icons.location_city_outlined,
                        value: _district,
                        items: _districts,
                        onChanged: (v) => setState(() => _district = v),
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.dangerSurface,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: c.danger.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 18, color: c.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                                color: c.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                AppPrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward,
                  height: 52,
                  loading: _isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.label,
    required this.icon,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? c.primaryLight : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? c.primary : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Icon(icon, size: 22, color: selected ? c.primary : c.textSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? c.primaryDark : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
