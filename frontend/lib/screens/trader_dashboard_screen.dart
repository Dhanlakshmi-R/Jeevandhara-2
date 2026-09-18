import 'package:flutter/material.dart';
import '../models/user.dart';
import '../theme/colors.dart';
import '../theme/locale.dart';
import '../widgets/dashboard_shell.dart';
import '../widgets/ui/buttons.dart';
import '../widgets/ui/cards.dart';
import 'market_prices_screen.dart';
import 'profile_screen.dart';

class TraderDashboardScreen extends StatefulWidget {
  final AppUser? user;

  const TraderDashboardScreen({super.key, this.user});

  @override
  State<TraderDashboardScreen> createState() => _TraderDashboardScreenState();
}

class _TraderDashboardScreenState extends State<TraderDashboardScreen> {
  static const _items = [
    ShellItem(labelKey: K.overview, icon: Icons.space_dashboard_outlined, selectedIcon: Icons.space_dashboard),
    ShellItem(labelKey: K.deals, icon: Icons.handshake_outlined, selectedIcon: Icons.handshake),
    ShellItem(labelKey: K.postOffer, icon: Icons.add_business_outlined, selectedIcon: Icons.add_business),
    ShellItem(labelKey: K.marketPrices, icon: Icons.trending_up, selectedIcon: Icons.trending_up),
    ShellItem(labelKey: K.profile, icon: Icons.person_outline, selectedIcon: Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      user: widget.user,
      items: _items,
      initialIndex: 0,
      showLocation: true,
      defaultLocation: 'Hubballi, Karnataka',
      mobileDestinations: const [0, 1, 2, 3, 4],
      pages: [
        TraderOverviewPage(user: widget.user),
        const TraderDealsPage(),
        const TraderPostOfferPage(),
        const MarketPricesScreen(),
        ProfileScreen(user: widget.user),
      ],
    );
  }
}

class TraderOverviewPage extends StatelessWidget {
  final AppUser? user;
  const TraderOverviewPage({this.user});

  static const _kpis = [
    _Kpi(icon: Icons.paid_outlined, label: 'This Season', value: '\u20B94,82,500'),
    _Kpi(icon: Icons.receipt_long_outlined, label: 'Active deals', value: '24'),
    _Kpi(icon: Icons.star_outline, label: 'Avg. rating', value: '4.6'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rawName = user?.name.trim() ?? '';
    final name = rawName.isEmpty ? 'Ramesh' : rawName.split(' ').first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Hero banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.primary, c.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good ${_greeting(context)}, $name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Here is today\u2019s trading overview.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.storefront, color: Colors.white, size: 32),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Featured alerts
        LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= 640;
            final a = _FeaturedDeal(title: 'Highest demand', subtitle: 'Wheat \u2014 prices up 5% this week', icon: Icons.trending_up, color: c.positive);
            const b = _FeaturedDeal(title: 'Price alert', subtitle: 'Tomato crossing \u20B94,000/quintal', icon: Icons.notifications_active_outlined, color: Color(0xFFF59E0B));
            if (sideBySide) {
              return Row(
                children: [
                  Expanded(child: a),
                  const SizedBox(width: 12),
                  Expanded(child: b),
                ],
              );
            }
            return Column(
              children: [
                a,
                const SizedBox(height: 12),
                b,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        // KPI grid
        AppCard(
          child: Row(
            children: [
              for (int i = 0; i < _kpis.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Icon(_kpis[i].icon, color: c.primary, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        _kpis[i].value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        _kpis[i].label,
                        style: TextStyle(fontSize: 11, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Quick deals
        SectionHeader(
          title: context.str(K.deals, fallback: 'Active Deals'),
          actionLabel: 'Post Offer',
          actionIcon: Icons.add,
          onAction: () {},
        ),
        const SizedBox(height: 10),
        for (final d in _deals)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DealCard(deal: d),
          ),
        const SizedBox(height: 8),
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.colors.accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_outline, color: Color(0xFFB47E00), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tip: Prices for onions are seasonally low. Consider posting a higher-volume offer to lock in better margins.',
                  style: TextStyle(fontSize: 12.5, color: c.textPrimary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.str(K.greetingMorning, fallback: 'morning');
    if (hour < 17) return context.str(K.greetingAfternoon, fallback: 'afternoon');
    return context.str(K.greetingEvening, fallback: 'evening');
  }
}

class _FeaturedDeal extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _FeaturedDeal({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  final _Deal deal;
  const _DealCard({required this.deal});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = deal.color(context);
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(deal.icon, color: c.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deal.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  '${deal.qty} \u2022 ${deal.price}',
                  style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                ),
              ],
            ),
          ),
          StatusBadge(text: deal.status, color: color, icon: Icons.verified),
        ],
      ),
    );
  }
}

class TraderDealsPage extends StatelessWidget {
  final ValueChanged<Map<String, String>>? onPostOffer;

  const TraderDealsPage({this.onPostOffer});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _deals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _DealCard(deal: _deals[index]),
    );
  }
}

class TraderPostOfferPage extends StatefulWidget {
  const TraderPostOfferPage({super.key});

  @override
  State<TraderPostOfferPage> createState() => _TraderPostOfferPageState();
}

class _TraderPostOfferPageState extends State<TraderPostOfferPage> {
  final _commodity = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();

  @override
  void dispose() {
    _commodity.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New buying offer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Reach nearby farmers instantly with a clear buying offer.',
                style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _commodity,
                style: TextStyle(color: c.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Commodity',
                  hintText: 'e.g. Tomato',
                  prefixIcon: Icon(Icons.eco_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: c.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Quantity (kg)',
                        hintText: 'e.g. 500',
                        prefixIcon: Icon(Icons.all_inbox_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: c.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Price / kg',
                        hintText: 'e.g. 32',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commodity,
                onChanged: (_) {},
                style: TextStyle(color: c.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Market',
                  hintText: 'Hubballi APMC',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: 'Post Offer',
                icon: Icons.send_outlined,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Offer posted to nearby farmers!')),
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: c.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offers are matched to farmers growing this crop within 80 km.',
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Kpi {
  final IconData icon;
  final String label;
  final String value;

  const _Kpi({required this.icon, required this.label, required this.value});
}

class _Deal {
  final String label;
  final String qty;
  final String price;
  final String status;
  final IconData icon;

  const _Deal({
    required this.label,
    required this.qty,
    required this.price,
    required this.status,
    required this.icon,
  });

  Color color(BuildContext context) {
    switch (status) {
      case 'Confirmed':
        return context.colors.positive;
      case 'Negotiating':
        return context.colors.accent;
      case 'In transit':
        return context.colors.info;
      default:
        return context.colors.warning;
    }
  }
}

const _deals = [
  _Deal(label: 'Tomato', qty: '1,200 kg', price: '\u20B934,800', status: 'Negotiating', icon: Icons.handshake_outlined),
  _Deal(label: 'Wheat', qty: '45 quintal', price: '\u20B91,01,250', status: 'Confirmed', icon: Icons.check_circle_outline),
  _Deal(label: 'Onion', qty: '800 kg', price: '\u20B926,400', status: 'In transit', icon: Icons.local_shipping_outlined),
  _Deal(label: 'Groundnut', qty: '60 quintal', price: '\u20B91,80,000', status: 'Payments due', icon: Icons.currency_rupee),
];