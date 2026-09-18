import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/locale.dart';
import '../widgets/agri_scene.dart';
import '../widgets/layout.dart';
import 'about_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'trader_dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  static const seenKey = 'onboarding_seen';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      kind: AgriSceneKind.sunrise,
      color: AppColors.primary,
      title: 'Sell crops at fair prices',
      subtitle: 'List your produce and connect directly with genuine traders. No middlemen, no unfair cuts.',
      points: [
        'Reach verified traders near you',
        'Compare best-offered rates',
        'Get paid faster & transparently',
      ],
    ),
    _Slide(
      kind: AgriSceneKind.weather,
      color: Color(0xFFF9A825),
      title: 'Weather + market, in your pocket',
      subtitle: 'Daily weather alerts and live market prices help you decide the right time and place to sell.',
      points: [
        'Hourly & 7-day weather forecasts',
        'Live APMC prices & trend insights',
        'Smart harvest and sowing advice',
      ],
    ),
    _Slide(
      kind: AgriSceneKind.tools,
      color: AppColors.earth,
      title: 'Everything your farm needs',
      subtitle: 'Rent equipment, buy quality inputs, and grow your farm with everything in one app.',
      points: [
        'Rent tractors, harvesters & more',
        'Order seeds, fertilizers & pesticides',
        'AI crop-quality scans & grading',
      ],
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.seenKey, true);
    if (!mounted) return;
    final api = ApiService();
    final loggedIn = await api.isLoggedIn();
    final role = await api.getSavedRole();
    Widget next;
    if (!loggedIn) {
      next = const LoginScreen();
    } else if (role != null && role != 'farmer') {
      next = const TraderDashboardScreen();
    } else {
      next = const HomeScreen();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AboutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final slide = _slides[_page];
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          Positioned(
            top: -110,
            right: -90,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: slide.color.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: -40,
            child: Icon(Icons.eco, size: 90, color: slide.color.withValues(alpha: 0.06)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [c.primary, c.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.eco_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Jeevandhara',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: c.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      const ThemeToggle(),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, index) {
                      final s = _slides[index];
                      final isActive = index == _page;
                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: isActive ? 1 : 0.55,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                          child: Column(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final art = Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(
                                          color: s.color.withValues(alpha: 0.28),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: c.shadow,
                                            blurRadius: 24,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: AgriScene(kind: s.kind, onDark: false),
                                    );
                                    if (constraints.maxWidth >= 560) {
                                      return Row(
                                        children: [
                                          Expanded(child: art),
                                          const SizedBox(width: 24),
                                          Expanded(child: _copy(s, c)),
                                        ],
                                      );
                                    }
                                    return Column(
                                      children: [
                                        Expanded(child: art),
                                        const SizedBox(height: 12),
                                        _copy(s, c),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 28 : 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? c.primary
                              : c.primary.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _page == _slides.length - 1
                          ? _finish
                          : () => _controller.nextPage(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOut,
                              ),
                      style: FilledButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      child: Text(_page == _slides.length - 1
                          ? context.str(K.getStarted)
                          : 'Next'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _page == _slides.length - 1 ? _finish : _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: _page == _slides.length - 1
                              ? c.textSecondary.withValues(alpha: 0.4)
                              : c.primary,
                        ),
                        child: const Text('Skip'),
                      ),
                      GestureDetector(
                        onTap: _openAbout,
                        child: Text(
                          'About our project',
                          style: TextStyle(
                            color: c.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: c.primary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _copy(_Slide s, ThemeColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: s.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Step ${_page + 1} of ${_slides.length}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: s.color,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          s.title,
          style: TextStyle(
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          s.subtitle,
          style: TextStyle(fontSize: 14.5, color: c.textSecondary, height: 1.55),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: s.color.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final point in s.points)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: s.color.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, size: 13, color: s.color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          point,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Slide {
  final AgriSceneKind kind;
  final Color color;
  final String title;
  final String subtitle;
  final List<String> points;

  const _Slide({
    required this.kind,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.points,
  });
}