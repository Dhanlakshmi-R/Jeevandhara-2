import 'package:flutter/material.dart';
import 'package:jeevandhara2/services/api_service.dart';
import 'package:jeevandhara2/services/auth_navigation.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/widgets/auth_layout.dart';
import 'package:jeevandhara2/widgets/agri_scene.dart';
import 'package:jeevandhara2/widgets/ui/app_input.dart';
import 'package:jeevandhara2/widgets/ui/buttons.dart';
import 'about_screen.dart';
import 'register_screen.dart';

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
      final result = await _apiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      navigateAfterAuth(context, result.user);
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
            validator: (v) =>
                (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
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
              Text('Remember me',
                  style: TextStyle(color: c.textPrimary, fontSize: 14)),
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
              style: TextStyle(
                  color: c.danger, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
