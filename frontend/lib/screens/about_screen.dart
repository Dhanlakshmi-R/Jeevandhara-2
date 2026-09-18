import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/ui/cards.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class AboutScreen extends StatelessWidget {
  final bool isLanding;
  const AboutScreen({super.key, this.isLanding = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _HeroCard(isLanding: isLanding),
          const SizedBox(height: 20),
          const _MissionCard(),
          const SizedBox(height: 24),
          const SectionHeader(title: 'What Jeevandhara Offers'),
          const SizedBox(height: 14),
          const _FeatureGrid(),
          const SizedBox(height: 24),
          const SectionHeader(title: 'How It Works'),
          const SizedBox(height: 14),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Step(step: '01', icon: Icons.app_registration, title: 'Create Your Profile', text: 'Sign up as a Farmer, Trader, or Vendor and set your village, crops, and preferences.'),
            const Divider(height: 1),
            const _Step(step: '02', icon: Icons.wb_sunny_outlined, title: 'Get Smart Decisions', text: 'AI crop-quality scans, daily weather alerts, and live market prices guide you on when and where to sell.'),
            const Divider(height: 1),
            const _Step(step: '03', icon: Icons.handshake_outlined, title: 'Sell, Rent & Grow', text: 'List produce, contact genuine traders, rent equipment, and order inputs \u2014 everything in one trusted place.'),
          ])),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Built for Everyone'),
          const SizedBox(height: 14),
          const _AudienceRow(),
          const SizedBox(height: 24),
          const _ValuesCard(),
          if (!isLanding) ...[const SizedBox(height: 14), const _JoinCta()],
          const SizedBox(height: 20),
          if (isLanding) ...[
            const SizedBox(height: 8),
            SizedBox(height: 54, width: double.infinity, child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen())),
              style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              icon: const Icon(Icons.rocket_launch_outlined, size: 20),
              label: const Text('Get Started'),
            )),
            const SizedBox(height: 12),
            SizedBox(height: 54, width: double.infinity, child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
              style: OutlinedButton.styleFrom(foregroundColor: c.primary, side: BorderSide(color: c.primary.withValues(alpha: 0.6), width: 1.4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              icon: const Icon(Icons.login, size: 20),
              label: const Text('Login'),
            )),
          ],
          const SizedBox(height: 20),
          Center(child: Text('Jeevandhara \u2014 Growing Prosperity, Together.', style: TextStyle(fontSize: 12.5, color: c.textSecondary))),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1F6B45), Color(0xFF0F3D28), Color(0xFF5C6BC0)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24)),
      child: Stack(children: [
        Positioned(top: -20, right: -10, child: Icon(Icons.eco, size: 90, color: Colors.white.withValues(alpha: 0.08))),
        Positioned(bottom: -20, left: -15, child: Icon(Icons.grass, size: 76, color: Colors.white.withValues(alpha: 0.06))),
        Column(children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: const Color(0x33000000), blurRadius: 16, offset: const Offset(0, 6))]), child: const Icon(Icons.spa_rounded, size: 44, color: Color(0xFF1F6B45))),
          const SizedBox(height: 16),
          const Text('Jeevandhara', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text('A digital platform that puts farmers first.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15)),
          const SizedBox(height: 18),
          const Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            _HeroPill(label: 'Fair Prices'),
            _HeroPill(label: 'No Middlemen'),
            _HeroPill(label: 'One App'),
          ]),
          if (isLanding) ...[
            const SizedBox(height: 28),
            SizedBox(height: 54, width: double.infinity, child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen())),
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1F6B45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              icon: const Icon(Icons.rocket_launch_outlined, size: 20),
              label: const Text('Get Started'),
            )),
            const SizedBox(height: 12),
            SizedBox(height: 54, width: double.infinity, child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.7), width: 1.4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              icon: const Icon(Icons.login, size: 20),
              label: const Text('Login'),
            )),
          ],
        ]),
      ]),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  const _HeroPill({required this.label});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.3))), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)));
}

class _MissionCard extends StatelessWidget {
  const _MissionCard();
  @override
  Widget build(BuildContext context) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(Icons.flag_rounded, color: context.colors.primary, size: 22), const SizedBox(width: 8), Text('Our Mission', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.colors.textPrimary))]),
    const SizedBox(height: 12),
    Text('Jeevandhara connects farmers directly with traders through transparent market prices, dependable weather intelligence, and trustworthy tools \u2014 so every grower earns the full value of their hard work.', style: TextStyle(fontSize: 14, color: context.colors.textSecondary, height: 1.55)),
  ]));
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();
  static const _features = [
    (Icons.wb_sunny_outlined, 'Weather Intelligence', 'Daily alerts & 7-day forecasts'),
    (Icons.trending_up, 'Live Market Prices', 'APMC prices & trend insights'),
    (Icons.sell_outlined, 'Sell My Crop', 'List produce for traders'),
    (Icons.handshake_outlined, 'Find Traders', 'Direct verified matches'),
    (Icons.agriculture_outlined, 'Tool Rental', 'Affordable farm equipment'),
    (Icons.biotech_outlined, 'AI Quality Scan', 'Instant crop grading'),
    (Icons.storefront_outlined, 'Inputs Marketplace', 'Seeds, fertilizers & more'),
    (Icons.notifications_active_outlined, 'Smart Alerts', 'Never miss a deal'),
  ];
  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _features.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 112),
    itemBuilder: (context, index) {
      final (icon, title, subtitle) = _features[index];
      return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.colors.border.withValues(alpha: 0.7)), boxShadow: [BoxShadow(color: context.colors.shadow, blurRadius: 8, offset: const Offset(0, 3))]), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1F6B45), Color(0xFF0F3D28)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14)), child: Icon(icon, size: 22, color: Colors.white)),
        const SizedBox(width: 12),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.colors.textPrimary)), const SizedBox(height: 3), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: context.colors.textSecondary, height: 1.3))])),
      ]));
    },
  );
}

class _Step extends StatelessWidget {
  final String step, title, text;
  final IconData icon;
  const _Step({required this.step, required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 44, height: 44, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1F6B45), Color(0xFF0F3D28)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14)), child: Center(child: Icon(icon, color: Colors.white, size: 20))),
    const SizedBox(width: 16),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text('STEP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: context.colors.primary.withValues(alpha: 0.8))), const SizedBox(width: 6), Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.colors.textPrimary)))]), const SizedBox(height: 6), Text(text, style: TextStyle(fontSize: 13, color: context.colors.textSecondary, height: 1.45))])),
  ]));
}

class _AudienceRow extends StatelessWidget {
  const _AudienceRow();
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
    Expanded(child: _AudienceCard(emoji: '\uD83C\uDF3E', title: 'Farmer', text: 'Grow, list & sell produce')),
    SizedBox(width: 10),
    Expanded(child: _AudienceCard(emoji: '\uD83D\uDC69\u200D\uD83D\uDCBC', title: 'Trader', text: 'Buy directly, fair margins')),
    SizedBox(width: 10),
    Expanded(child: _AudienceCard(emoji: '\uD83C\uDFE9', title: 'Vendor', text: 'Supply quality inputs')),
  ]);
}

class _AudienceCard extends StatelessWidget {
  final String emoji, title, text;
  const _AudienceCard({required this.emoji, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.colors.border.withValues(alpha: 0.7))), child: Column(children: [Text(emoji, style: const TextStyle(fontSize: 26)), const SizedBox(height: 6), Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: context.colors.textPrimary)), const SizedBox(height: 3), Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: context.colors.textSecondary, height: 1.3))]));
}

class _ValuesCard extends StatelessWidget {
  const _ValuesCard();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE5F2E9), Color(0xFFFFF6DE)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1F6B45).withValues(alpha: 0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(Icons.favorite_rounded, color: context.colors.primary, size: 20), const SizedBox(width: 8), Text('What We Believe In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.colors.textPrimary))]),
    const SizedBox(height: 14),
    const _ValueRow(icon: Icons.balance_rounded, text: 'Fairness & transparent trade for every farmer'),
    const SizedBox(height: 10),
    const _ValueRow(icon: Icons.language_rounded, text: 'Technology in local languages for every grower'),
    const SizedBox(height: 10),
    const _ValueRow(icon: Icons.verified_rounded, text: 'Trusted traders and verified partners only'),
  ]));
}

class _ValueRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ValueRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: context.colors.primary), const SizedBox(width: 10), Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, color: context.colors.textPrimary, height: 1.4)))]);
}

class _JoinCta extends StatelessWidget {
  const _JoinCta();
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Navigator.of(context).pop(), style: OutlinedButton.styleFrom(foregroundColor: context.colors.primary, side: BorderSide(color: context.colors.primary, width: 1.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), icon: const Icon(Icons.arrow_back, size: 20), label: const Text('Go Back')));
}