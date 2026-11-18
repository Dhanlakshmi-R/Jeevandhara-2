import 'package:flutter/material.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';
import 'package:jeevandhara2/widgets/ui/network_or_asset_image.dart';
import 'package:jeevandhara2/widgets/hero_carousel.dart';
import 'package:jeevandhara2/widgets/step_card.dart';
import 'package:jeevandhara2/widgets/feature_tile.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class AboutScreen extends StatelessWidget {
  final bool isLanding;
  const AboutScreen({super.key, this.isLanding = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      backgroundColor: c.background,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(isLanding: isLanding),
                _buildHero(context, isLanding),
                const SizedBox(height: 12),
                _TrustStrip(),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SectionHeader(title: 'How it works'),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Expanded(
                                child: StepCard(
                              number: '01',
                              title: 'Create profile',
                              description:
                                  'Sign up as Farmer, Trader or Vendor and set your village, crops and preferences.',
                              icon: Icons.app_registration,
                              imageUrl:
                                  'https://images.unsplash.com/photo-1593113598332-cd288d649433?w=600&q=80',
                            )),
                            SizedBox(width: 12),
                            Expanded(
                                child: StepCard(
                              number: '02',
                              title: 'Get smart decisions',
                              description:
                                  'AI crop-quality scans, daily weather alerts and live market prices guide you.',
                              icon: Icons.wb_sunny_outlined,
                              imageUrl:
                                  'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=600&q=80',
                            )),
                            SizedBox(width: 12),
                            Expanded(
                                child: StepCard(
                              number: '03',
                              title: 'Sell, rent & grow',
                              description:
                                  'List produce, contact traders, rent equipment and order inputs in one place.',
                              icon: Icons.handshake_outlined,
                              imageUrl:
                                  'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=600&q=80',
                            )),
                          ],
                        )
                      : const Column(
                          children: [
                            StepCard(
                              number: '01',
                              title: 'Create profile',
                              description:
                                  'Sign up as Farmer, Trader or Vendor and set your village, crops and preferences.',
                              icon: Icons.app_registration,
                              imageUrl:
                                  'https://images.unsplash.com/photo-1593113598332-cd288d649433?w=600&q=80',
                            ),
                            SizedBox(height: 12),
                            StepCard(
                              number: '02',
                              title: 'Get smart decisions',
                              description:
                                  'AI crop-quality scans, daily weather alerts and live market prices guide you.',
                              icon: Icons.wb_sunny_outlined,
                              imageUrl:
                                  'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=600&q=80',
                            ),
                            SizedBox(height: 12),
                            StepCard(
                              number: '03',
                              title: 'Sell, rent & grow',
                              description:
                                  'List produce, contact traders, rent equipment and order inputs in one place.',
                              icon: Icons.handshake_outlined,
                              imageUrl:
                                  'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=600&q=80',
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SectionHeader(title: 'What Jeevandhara offers'),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _features.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 4 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 96,
                    ),
                    itemBuilder: (context, index) {
                      final f = _features[index];
                      return FeatureTile(
                        icon: f.$1,
                        title: f.$2,
                        subtitle: f.$3,
                        gradientColors: f.$4,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SectionHeader(title: 'Built for everyone'),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                          child: _AudienceCard(
                        emoji: '\uD83C\uDF3E',
                        title: 'Farmer',
                        text: 'Grow, list & sell produce',
                        imageUrl:
                            'https://images.unsplash.com/photo-1593113598332-cd288d649433?w=400&q=80',
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _AudienceCard(
                        emoji: '\uD83E\uDDD1\u200D\uD83D\uDCBC',
                        title: 'Trader',
                        text: 'Buy directly, fair margins',
                        imageUrl:
                            'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=400&q=80',
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _AudienceCard(
                        emoji: '\uD83C\uDFE9',
                        title: 'Vendor',
                        text: 'Supply quality inputs',
                        imageUrl:
                            'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=400&q=80',
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ValuesCard(),
                ),
                if (isLanding) ...[
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _FooterCta(),
                  ),
                ],
                const SizedBox(height: 32),
                _Footer(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, bool isLanding) {
    final primaryBtn = SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingScreen())),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F6B45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        icon: const Icon(Icons.rocket_launch_outlined, size: 20),
        label: const Text('Get Started'),
      ),
    );
    final secondaryBtn = SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen())),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
              color: Colors.white.withValues(alpha: 0.7), width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        icon: const Icon(Icons.login, size: 20),
        label: const Text('Login'),
      ),
    );

    if (isLanding) {
      return HeroCarousel(
        slides: const [
          HeroSlide(
            title: 'Grow more. Earn more. Together.',
            subtitle:
                'Direct market access, live prices, weather & tools — one app for every farmer.',
            imageUrl:
                'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=1200&q=80',
          ),
          HeroSlide(
            title: 'Fair prices, no middlemen.',
            subtitle: 'Connect directly with verified traders and mandis.',
            imageUrl:
                'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=1200&q=80',
          ),
          HeroSlide(
            title: 'Everything your farm needs.',
            subtitle: 'Weather, tools, inputs and AI quality scans in one place.',
            imageUrl:
                'https://images.unsplash.com/photo-1593113598332-cd288d649433?w=1200&q=80',
          ),
        ],
        primaryButton: primaryBtn,
        secondaryButton: secondaryBtn,
      );
    }

    return _HeroCard(isLanding: false);
  }
}

class _TopBar extends StatelessWidget {
  final bool isLanding;
  const _TopBar({required this.isLanding});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(Icons.eco_rounded, color: c.primary, size: 26),
          const SizedBox(width: 8),
          Text(
            'Jeevandhara',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (isLanding) ...[
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text('Login'),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen())),
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Get Started'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _TrustItem(label: '10,000+ farmers'),
          _TrustItem(label: '500+ traders'),
          _TrustItem(label: '24/7 support'),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final String label;
  const _TrustItem({required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(
      label, // TODO: replace placeholder metrics with real counts
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: context.colors.textSecondary,
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool isLanding;
  const _HeroCard({required this.isLanding});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F6B45), Color(0xFF0F3D28), Color(0xFF5C6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.spa_rounded,
                size: 44, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text('Jeevandhara',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text('A digital platform that puts farmers first.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9), fontSize: 15)),
        ],
      ),
    );
  }
}

// Feature data
const _features = [
  (Icons.wb_sunny_outlined, 'Weather Intelligence', 'Daily alerts & 7-day forecasts',
      [Color(0xFF5C6BC0), Color(0xFF3949AB)]),
  (Icons.trending_up, 'Live Market Prices', 'APMC prices & trend insights',
      [Color(0xFF1F6B45), Color(0xFF0F3D28)]),
  (Icons.sell_outlined, 'Sell My Crop', 'List produce for traders',
      [Color(0xFFF9A825), Color(0xFFE65100)]),
  (Icons.handshake_outlined, 'Find Traders', 'Direct verified matches',
      [Color(0xFF795548), Color(0xFF4E342E)]),
  (Icons.agriculture_outlined, 'Tool Rental', 'Affordable farm equipment',
      [Color(0xFF1F6B45), Color(0xFF0F3D28)]),
  (Icons.biotech_outlined, 'AI Quality Scan', 'Instant crop grading',
      [Color(0xFF5C6BC0), Color(0xFF3949AB)]),
  (Icons.storefront_outlined, 'Inputs Marketplace', 'Seeds, fertilizers & more',
      [Color(0xFFF9A825), Color(0xFFE65100)]),
  (Icons.notifications_active_outlined, 'Smart Alerts', 'Never miss a deal',
      [Color(0xFF795548), Color(0xFF4E342E)]),
];

class _AudienceCard extends StatelessWidget {
  final String emoji, title, text;
  final String? imageUrl;
  const _AudienceCard({
    required this.emoji,
    required this.title,
    required this.text,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (imageUrl != null)
            SizedBox(
              height: 70,
              width: double.infinity,
              child: NetworkOrAssetImage(url: imageUrl, width: double.infinity, height: 70, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(title,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        color: c.textSecondary,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuesCard extends StatelessWidget {
  const _ValuesCard();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE5F2E9), Color(0xFFFFF6DE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF1F6B45).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.favorite_rounded, color: c.primary, size: 20),
            const SizedBox(width: 8),
            Text('What We Believe In',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary))
          ]),
          const SizedBox(height: 14),
          const _ValueRow(
              icon: Icons.balance_rounded,
              text: 'Fairness & transparent trade for every farmer'),
          const SizedBox(height: 10),
          const _ValueRow(
              icon: Icons.language_rounded,
              text: 'Technology in local languages for every grower'),
          const SizedBox(height: 10),
          const _ValueRow(
              icon: Icons.verified_rounded,
              text: 'Trusted traders and verified partners only'),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ValueRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: c.primary),
      const SizedBox(width: 10),
      Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13.5,
                  color: c.textPrimary,
                  height: 1.4))),
    ]);
  }
}

class _FooterCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F6B45), Color(0xFF0F3D28)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'Ready to grow? Get started in 2 minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (_) => const OnboardingScreen())),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1F6B45),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Get Started',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen())),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.7), width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Login',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.eco_rounded, color: c.primary, size: 20),
              const SizedBox(width: 6),
              Text('Jeevandhara',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: c.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _FooterLink(label: 'About'),
              _FooterLink(label: 'Privacy'),
              _FooterLink(label: 'Terms'),
              _FooterLink(label: 'Contact'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            children: const [
              Icon(Icons.language, size: 18),
              Icon(Icons.facebook, size: 18),
              Icon(Icons.alternate_email, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Language: EN  \u00b7  KN (placeholder)',
            style: TextStyle(fontSize: 11.5, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  const _FooterLink({required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12.5,
        color: context.colors.textSecondary,
        decoration: TextDecoration.underline,
      ),
    );
  }
}