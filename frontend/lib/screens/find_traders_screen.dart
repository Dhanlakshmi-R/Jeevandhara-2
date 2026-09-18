import 'package:flutter/material.dart';
import '../models/trader.dart';
import '../theme/colors.dart';
import '../widgets/ui/buttons.dart';
import '../widgets/ui/cards.dart';
import '../widgets/ui/states.dart';

class FindTradersScreen extends StatefulWidget {
  const FindTradersScreen({super.key});

  @override
  State<FindTradersScreen> createState() => _FindTradersScreenState();
}

class _FindTradersScreenState extends State<FindTradersScreen> {
  final List<Trader> _all = Trader.sampleData();
  final TextEditingController _search = TextEditingController();
  String _filter = 'All';

  List<String> get _cropFilters {
    final crops = <String>{};
    for (final t in _all) {
      crops.add(t.cropType);
    }
    return ['All', ...crops];
  }

  List<Trader> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _all.where((t) {
      final matchQ = q.isEmpty ||
          t.name.toLowerCase().contains(q) ||
          t.company.toLowerCase().contains(q) ||
          t.cropType.toLowerCase().contains(q);
      final matchF = _filter == 'All' || t.cropType == _filter;
      return matchQ && matchF;
    }).toList();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _contactTraders(List<Trader> traders) {
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contact traders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary),
              ),
              const SizedBox(height: 12),
              for (final t in traders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: c.primaryLight,
                        child: Text(t.emoji),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${t.name} \u2022 ${t.company}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                              ),
                            ),
                            Text(
                              t.phone,
                              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.phone_outlined, color: c.primary),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              AppPrimaryButton(
                label: 'Done',
                height: 46,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: c.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Search by name, company or crop',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: _cropFilters
                .map((crop) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(crop, style: const TextStyle(fontSize: 12.5)),
                        selected: _filter == crop,
                        onSelected: (_) => setState(() => _filter = crop),
                        selectedColor: c.primaryLight,
                        side: BorderSide(color: _filter == crop ? c.primary : c.border),
                        labelStyle: TextStyle(
                          color: _filter == crop ? c.primaryDark : c.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'No traders found',
                  subtitle: 'Try adjusting your search or filters.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _TraderCard(
                    trader: _filtered[index],
                    onCall: () => _contactTraders([_filtered[index]]),
                  ),
                ),
        ),
        if (_filtered.isNotEmpty)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.divider)),
              ),
              child: AppPrimaryButton(
                label: 'Contact best-matching traders',
                icon: Icons.forum_outlined,
                height: 46,
                onPressed: () => _contactTraders(_filtered),
              ),
            ),
          ),
      ],
    );
  }
}

class _TraderCard extends StatelessWidget {
  final Trader trader;
  final VoidCallback onCall;

  const _TraderCard({required this.trader, required this.onCall});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: c.surfaceAlt,
                child: Text(trader.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            trader.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(Icons.star, size: 16, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          trader.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      trader.company,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 13, color: c.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          '${trader.location} \u2022 ${trader.distance} away',
                          style: TextStyle(fontSize: 12, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${trader.cropType}: ${trader.offeredPrice}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTonalButton(
                  label: trader.available ? 'Call now' : 'Currently busy',
                  icon: trader.available ? Icons.call_outlined : Icons.hourglass_empty,
                  onPressed: onCall,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppOutlineButton(
                  label: 'Chat',
                  icon: Icons.forum_outlined,
                  height: 44,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat coming soon')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}