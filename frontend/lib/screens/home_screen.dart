import 'package:flutter/material.dart';

import 'package:jeevandhara2/app/destinations.dart';
import 'package:jeevandhara2/app/shell/app_shell.dart';
import 'package:jeevandhara2/models/market_price.dart';
import 'package:jeevandhara2/models/trader.dart';
import 'package:jeevandhara2/models/user.dart';
import 'package:jeevandhara2/models/weather.dart';
import 'package:jeevandhara2/services/api_service.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/widgets/layout.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';
import 'package:jeevandhara2/widgets/weather_card.dart';

/// The farmer's entry point.
///
/// The chat is now the landing surface and the sidebar carries the rest, so
/// this is a thin wrapper over [AppShell] rather than a page of its own. The
/// dashboard survives as [FarmerDashboardPage] and is reachable from the
/// sidebar and the command palette.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.user});

  /// Passed by the login flow so the avatar is right on the first frame. The
  /// shell refetches the profile itself, so omitting it is fine too.
  final AppUser? user;

  @override
  Widget build(BuildContext context) =>
      AppShell(role: AppRole.farmer, initialUser: user);
}

/// The farmer's overview page.
///
/// [user] and [onRefresh] are optional so this can be constructed straight
/// from the destination registry; when omitted it fetches the current user
/// itself and refreshes on pull.
class FarmerDashboardPage extends StatefulWidget {
  final AppUser? user;
  final Future<void> Function()? onRefresh;

  const FarmerDashboardPage({super.key, this.user, this.onRefresh});

  @override
  State<FarmerDashboardPage> createState() => FarmerDashboardPageState();
}

class FarmerDashboardPageState extends State<FarmerDashboardPage> {
  final _apiService = ApiService();
  AppUser? _ownUser;
  bool _loading = false;

  AppUser? get _user => widget.user ?? _ownUser;

  @override
  void initState() {
    super.initState();
    // Only fetch when nobody upstream supplied the user, so a shell that
    // already loaded it does not pay for a second round trip.
    if (widget.user == null) _loadUser();
  }

  Future<void> _loadUser() async {
    if (_loading) return;
    _loading = true;
    try {
      final user = await _apiService.getCurrentUser();
      if (mounted) setState(() => _ownUser = user);
    } catch (_) {
      // An unauthenticated or offline session just leaves the stats as they
      // are; this page is still useful without them.
    } finally {
      _loading = false;
    }
  }

  Future<void> _refresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
      return;
    }
    await _loadUser();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const SizedBox(height: 8),
          _WelcomeBanner(name: _user?.name),
          const SizedBox(height: 20),
          _DashboardGrid(),
          const SizedBox(height: 20),
          _buildQuickActions(),
          const SizedBox(height: 20),
          const _RecentSection(),
          const SizedBox(height: 20),
          const _TipCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
            title: 'Quick Actions',
            actionLabel: 'View All',
            actionIcon: Icons.chevron_right),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = responsiveCols(constraints.maxWidth);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisExtent: 128,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _quickActions.length,
              itemBuilder: (context, i) =>
                  _QuickActionCard(spec: _quickActions[i]),
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionSpec {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionSpec(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.onTap});
}

class _QuickActionCard extends StatelessWidget {
  final _QuickActionSpec spec;
  const _QuickActionCard({required this.spec});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: spec.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: spec.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(spec.icon, color: spec.color, size: 22)),
              const Spacer(),
              Text(spec.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
              const SizedBox(height: 2),
              Text(spec.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({this.name});

  /// The signed-in farmer. Falls back to a neutral label rather than a
  /// hardcoded name when the profile has not loaded yet.
  final String? name;

  String get _firstName {
    final raw = (name ?? '').trim();
    if (raw.isEmpty) return 'Farmer';
    return raw.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final greeting = _greeting(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c.primary, c.primaryDark]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: c.primary.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 10))
          ]),
      child: Stack(children: [
        Positioned(
            right: -40,
            top: -50,
            child: Icon(Icons.eco_rounded,
                size: 180, color: Colors.white.withValues(alpha: 0.06))),
        Positioned(
            right: 50,
            bottom: -50,
            child: Icon(Icons.grass_rounded,
                size: 140, color: Colors.white.withValues(alpha: 0.05))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(greeting,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(_firstName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('Welcome back to your farm dashboard.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
          const SizedBox(height: 16),
          const Wrap(spacing: 10, runSpacing: 10, children: [
            _BannerStat(
                icon: Icons.landscape_outlined,
                value: '2.4 acres',
                label: 'Land'),
            _BannerStat(
                icon: Icons.eco_outlined, value: '5 crops', label: 'Active'),
            _BannerStat(
                icon: Icons.inventory_2_outlined,
                value: '250 kg',
                label: 'To sell'),
          ]),
        ]),
      ]),
    );
  }

  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _BannerStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _BannerStat(
      {required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
      ]),
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  _DashboardGrid();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
            title: 'Weather Summary',
            actionLabel: 'Details',
            actionIcon: Icons.arrow_forward_ios),
        const SizedBox(height: 10),
        WeatherCard(weather: Weather.sampleDharwad(), onMore: () {}),
        const SizedBox(height: 20),
        const SectionHeader(
            title: 'Live Market Prices',
            actionLabel: 'View All',
            actionIcon: Icons.trending_up),
        const SizedBox(height: 10),
        SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _prices.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _MiniPriceCard(price: _prices[i]),
            )),
      ],
    );
  }

  final List<MarketPrice> _prices = MarketPrice.sampleData();
}

class _MiniPriceCard extends StatelessWidget {
  final MarketPrice price;
  const _MiniPriceCard({required this.price});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final trendColor = price.isRising ? c.positive : c.negative;
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
                color: c.shadow, blurRadius: 8, offset: const Offset(0, 3))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(price.emoji, style: const TextStyle(fontSize: 24)),
          const Spacer(),
          StatusBadge(
              text: price.changePercent >= 0
                  ? '+${price.changePercent.toStringAsFixed(1)}%'
                  : '${price.changePercent.toStringAsFixed(1)}%',
              color: trendColor)
        ]),
        const Spacer(),
        Text(price.crop,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textPrimary)),
        Text(price.priceLabel,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: c.primaryDark)),
      ]),
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final sideBySide = constraints.maxWidth >= 840;
      if (sideBySide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _ListingsCard()),
          const SizedBox(width: 16),
          Expanded(child: _OffersCard())
        ]);
      }
      return Column(children: [
        _ListingsCard(),
        const SizedBox(height: 16),
        _OffersCard()
      ]);
    });
  }
}

class _ListingsCard extends StatelessWidget {
  const _ListingsCard();
  @override
  Widget build(BuildContext context) {
    return AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Recent Crop Listings',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary)),
            TextButton(onPressed: () {}, child: const Text('View all'))
          ]),
          const Divider(),
          const SizedBox(height: 8),
          ...CropListingSample.samples.map((c) => _CropRow(crop: c)),
        ]));
  }
}

class CropListingSample {
  static const samples = [
    CropRowData('\uD83C\uDF45', 'Tomato', '250 kg', 'Active', '\u20B928/kg'),
    CropRowData('\uD83C\uDF3E', 'Wheat', '5 quintal', 'Offer received',
        '\u20B92,200/q'),
    CropRowData('\uD83E\uDDC5', 'Onion', '1 quintal', 'Sold', '\u20B936/kg'),
  ];
}

class CropRowData {
  final String emoji, name, qty, status, price;
  const CropRowData(this.emoji, this.name, this.qty, this.status, this.price);
}

class _CropRow extends StatelessWidget {
  final CropRowData crop;
  const _CropRow({required this.crop});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final statusColor = crop.status == 'Sold'
        ? c.textSecondary
        : crop.status == 'Offer received'
            ? c.accent
            : c.positive;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: c.primaryLight,
                  borderRadius: BorderRadius.circular(14)),
              child: Center(
                  child:
                      Text(crop.emoji, style: const TextStyle(fontSize: 26)))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(crop.name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
                Text(crop.qty,
                    style: TextStyle(fontSize: 12, color: c.textSecondary))
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(crop.price,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.primaryDark)),
            const SizedBox(height: 3),
            StatusBadge(text: crop.status, color: statusColor)
          ]),
        ]));
  }
}

class _OffersCard extends StatelessWidget {
  const _OffersCard();
  @override
  Widget build(BuildContext context) {
    return AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Recent Trader Offers',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary)),
            TextButton(onPressed: () {}, child: const Text('View all'))
          ]),
          const Divider(),
          const SizedBox(height: 8),
          ...Trader.sampleData().take(3).map((t) => _OfferRow(trader: t)),
        ]));
  }
}

class _OfferRow extends StatelessWidget {
  final Trader trader;
  const _OfferRow({required this.trader});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: c.primaryLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text(trader.emoji,
                      style: const TextStyle(fontSize: 22)))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(trader.name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
                Text('${trader.cropType} \u2022 ${trader.distance}',
                    style: TextStyle(fontSize: 12, color: c.textSecondary))
              ])),
          StatusBadge(text: trader.offeredPrice, color: c.positive),
        ]));
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [c.accentLight, c.accent.withValues(alpha: 0.2)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.accent.withValues(alpha: 0.4))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: c.accent, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.lightbulb_outlined,
                color: Colors.black87, size: 24)),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Farming Tip of the Day',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textOnAccent)),
          const SizedBox(height: 8),
          Text(
              'Water your crops early in the morning to reduce evaporation. Soil moisture is highest before sunrise \u2014 you can save up to 30% water.',
              style: TextStyle(
                  fontSize: 13.5, height: 1.45, color: c.textOnAccent))
        ])),
      ]),
    );
  }
}

final List<_QuickActionSpec> _quickActions = [
  _QuickActionSpec(
      title: 'Sell Crop',
      subtitle: 'List produce to traders',
      icon: Icons.sell_outlined,
      color: const Color(0xFF1F6B45),
      onTap: () {}),
  _QuickActionSpec(
      title: 'Analyze Quality',
      subtitle: 'AI grade & scan crops',
      icon: Icons.biotech_outlined,
      color: const Color(0xFF5DAE54),
      onTap: () {}),
  _QuickActionSpec(
      title: 'Find Traders',
      subtitle: 'Matched buyers nearby',
      icon: Icons.handshake_outlined,
      color: const Color(0xFFF4B942),
      onTap: () {}),
  _QuickActionSpec(
      title: 'Rent Tools',
      subtitle: 'Tractors & equipment',
      icon: Icons.agriculture_outlined,
      color: const Color(0xFF2E86AB),
      onTap: () {}),
];
