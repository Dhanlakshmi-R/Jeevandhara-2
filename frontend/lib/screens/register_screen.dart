import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../widgets/agri_scene.dart';
import '../widgets/auth_layout.dart';
import '../widgets/ui/buttons.dart';
import '../widgets/ui/app_input.dart';
import 'about_screen.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _apiService = ApiService();

  static const _states = [
    'Karnataka', 'Maharashtra', 'Tamil Nadu', 'Andhra Pradesh', 'Telangana', 'Gujarat', 'Punjab', 'Madhya Pradesh',
  ];

  static const _districts = [
    'Belagavi', 'Ballari', 'Dharwad', 'Gadag', 'Haveri', 'Kolar', 'Mysuru', 'Raichur', 'Tumakuru', 'Udupi',
  ];

  String _role = 'farmer';
  String? _state;
  String? _district;
  bool _acceptTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      setState(() => _errorMessage = 'Please accept the terms & conditions');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final location = [_district, _state].whereType<String>().join(', ');
      await _apiService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _role,
        phone: _mobileController.text.trim(),
        location: location.isEmpty ? null : location,
      );
      await _apiService.saveUserRole(_role);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created \u2014 please log in')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleRegister() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF1F6B45)),
              const SizedBox(height: 14),
              Text('Creating Google account\u2026',
                  style: TextStyle(color: dialogContext.colors.textPrimary)),
            ],
          ),
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.of(context).pop();
    await _apiService.saveUserRole('farmer');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed up with Google (demo)')),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      headline: 'Join Jeevandhara',
      subhead: 'Set up your account and start farming smarter.',
      scene: AgriSceneKind.weather,
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
          Text('I am a', style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary, fontSize: 14.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _RoleCard(
                label: 'Farmer',
                icon: Icons.agriculture_outlined,
                emoji: '\uD83D\uDC33',
                selected: _role == 'farmer',
                onTap: () => setState(() => _role = 'farmer'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _RoleCard(
                label: 'Trader',
                icon: Icons.storefront_outlined,
                emoji: '\uD83E\uDDD1\u200D\uD83D\uDCBC',
                selected: _role == 'trader',
                onTap: () => setState(() => _role = 'trader'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _RoleCard(
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
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _mobileController,
            label: 'Mobile number',
            icon: Icons.phone_android,
            keyboardType: TextInputType.phone,
            validator: (v) =>
                (v == null || v.length < 10) ? 'Enter a valid 10-digit number' : null,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _confirmController,
            label: 'Confirm password',
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (v) => (v != _passwordController.text) ? 'Passwords do not match' : null,
            textInputAction: TextInputAction.done,
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
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acceptTerms,
                activeColor: c.primary,
                onChanged: (v) => setState(() => _acceptTerms = v ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'I agree to the Terms & Conditions and Privacy Policy',
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          if (_errorMessage != null) _errorBanner(c, _errorMessage!),
          AppPrimaryButton(
            label: 'Create Account',
            icon: Icons.person_add_alt_1,
            loading: _isLoading,
            onPressed: _handleRegister,
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _googleRegister,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.textPrimary,
                side: BorderSide(color: c.border, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
              icon: Icon(Icons.g_mobiledata, color: c.primary, size: 22),
              label: const Text('Continue with Google'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: TextStyle(color: c.textSecondary, fontSize: 14),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Text(
                  'Log in',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
      margin: const EdgeInsets.only(bottom: 12),
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