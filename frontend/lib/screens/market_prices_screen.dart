import 'package:flutter/material.dart';
import '../models/market_price.dart';
import '../theme/colors.dart';
import '../widgets/ui/cards.dart';
import '../widgets/ui/states.dart';

class MarketPricesScreen extends StatefulWidget {
  const MarketPricesScreen({super.key});

  @override
  State<MarketPricesScreen> createState() => _MarketPricesScreenState();
}

class _MarketPricesScreenState extends State<MarketPricesScreen> {
  final List<MarketPrice> _all = MarketPrice.sampleData();
  final TextEditingController _search = TextEditingController();
  String _market = 'Hubballi APMC';
  String? _filter;

  static const _markets = ['Hubballi APMC', 'Dharwad Market', 'Belagavi APMC', 'Gadag Market'];

  List<MarketPrice> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _all.where((p) {
      final matchQ = q.isEmpty ||
          p.crop.toLowerCase().contains(q) ||
          p.unit.toLowerCase().contains(q);
      final matchFilter = _filter == null || p.trendLabel == _filter;
      return matchQ && matchFilter;
    }).toList();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _all.isEmpty
        ? const EmptyState(
            icon: Icons.trending_up,
            title: 'No market data',
            subtitle: 'Prices will appear here once the market feed connects.',
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: c.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Search crops',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.filter_list, color: c.primary),
                      tooltip: 'Filter',
                      onSelected: (v) => setState(() => _filter = v),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'All trends', child: Text('All trends')),
                        for (final t in ['Rising', 'Stable', 'Falling'])
                          PopupMenuItem(value: t, child: Text(t)),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    for (final m in _markets) ...[
                      _MarketChip(
                        label: m,
                        selected: _market == m,
                        onTap: () => setState(() => _market = m),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: _filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'No crops found',
                        subtitle: 'Try a different search or filter.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _PriceDetailCard(
                          price: _filtered[index],
                          market: _market,
                        ),
                      ),
              ),
            ],
          );
  }
}

class _MarketChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MarketChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c.primary : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PriceDetailCard extends StatelessWidget {
  final MarketPrice price;
  final String market;

  const _PriceDetailCard({required this.price, required this.market});

  Color _trendColor(BuildContext context) {
    final c = context.colors;
    switch (price.trendLabel) {
      case 'Rising':
        return c.positive;
      case 'Falling':
        return c.danger;
      default:
        return c.warning;
    }
  }

  String get _suggestion {
    switch (price.trendLabel) {
      case 'Rising':
        return 'Good time to sell \u2014 prices are rising.';
      case 'Falling':
        return 'Consider holding or negotiating a better price.';
      default:
        return 'Prices are stable \u2014 monitor before selling.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final trend = price.weekTrend;
    final maxV = trend.reduce((a, b) => a > b ? a : b);
    final trendColor = _trendColor(context);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: c.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(price.emoji, style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      price.crop,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      '$market \u2022 per ${price.unit}',
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price.priceLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: c.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(
                    text: '${price.trendLabel} ${price.changePercent >= 0 ? '+' : ''}${price.changePercent.toStringAsFixed(1)}%',
                    color: trendColor,
                    icon: price.isRising ? Icons.arrow_upward : Icons.arrow_downward,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '7-day trend',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.textSecondary),
              ),
              const SizedBox(width: 8),
              for (final v in trend)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 42,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: (v / maxV) * 40,
                      decoration: BoxDecoration(
                        color: trendColor.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.insights_outlined, size: 16, color: c.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Suggested decision: $_suggestion',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.textPrimary,
                      fontWeight: FontWeight.w500,
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
}