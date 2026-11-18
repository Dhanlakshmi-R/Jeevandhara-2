import 'package:flutter/material.dart';

import 'package:jeevandhara2/models/trader.dart';
import 'package:jeevandhara2/services/listings_service.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/widgets/ui/buttons.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';
import 'package:jeevandhara2/widgets/ui/states.dart';

class FindTradersScreen extends StatefulWidget {
  final ListingsService? service;

  const FindTradersScreen({super.key, this.service});

  @override
  State<FindTradersScreen> createState() => _FindTradersScreenState();
}

class _FindTradersScreenState extends State<FindTradersScreen> {
  late final ListingsService _service =
      widget.service ?? ListingsService();
  final List<Trader> _all = [];
  final TextEditingController _search = TextEditingController();
  bool _loading = true;
  String? _error;
  String _filter = 'All';

  List<String> get _cropFilters {
    final crops = <String>{};
    for (final t in _all) {
      crops.addAll(t.crops);
    }
    return ['All', ...crops];
  }

  List<Trader> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _all.where((t) {
      final matchQ = q.isEmpty ||
          t.name.toLowerCase().contains(q) ||
          t.company.toLowerCase().contains(q) ||
          t.crops.any((cr) => cr.toLowerCase().contains(q));
      final matchF = _filter == 'All' || t.crops.contains(_filter);
      return matchQ && matchF;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = _all.isEmpty;
      _error = null;
    });
    try {
      final traders = await _service.traders();
      if (!mounted) return;
      setState(() {
        _all
          ..clear()
          ..addAll(traders);
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _contactTraders(List<Trader> traders) async {
    final reachable = traders.where((t) => t.phone != null).toList();
    final c = context.colors;
    if (reachable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No phone numbers shared yet. Message the card poster inside the app instead.')),
      );
      return;
    }
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
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary),
              ),
              const SizedBox(height: 12),
              for (final t in reachable)
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
                              '${t.name} \u2022 ${t.company.isNotEmpty ? t.company : 'Trader'}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                              ),
                            ),
                            Text(
                              t.phone!,
                              style: TextStyle(
                                  fontSize: 12.5, color: c.textSecondary),
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

  Future<void> _registerAsTrader() async {
    // The form itself handles auth failures (401 -> "please sign in").
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _TraderCardForm(onDone: () async {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(context).pop();
          await _reload();
          messenger.showSnackBar(
            const SnackBar(
                content: Text(
                    'Your card is live. Farmers near you can now find you.')),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load traders',
        subtitle: _error!,
        actionLabel: 'Try again',
        onAction: _reload,
      );
    }
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
        if (_all.isNotEmpty)
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: _cropFilters
                  .map((crop) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(crop,
                              style: const TextStyle(fontSize: 12.5)),
                          selected: _filter == crop,
                          onSelected: (_) => setState(() => _filter = crop),
                          selectedColor: c.primaryLight,
                          side: BorderSide(
                              color: _filter == crop ? c.primary : c.border),
                          labelStyle: TextStyle(
                            color: _filter == crop
                                ? c.primaryDark
                                : c.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        Expanded(
          child: _filtered.isEmpty
              ? EmptyState(
                  icon: Icons.person_search_outlined,
                  title: _all.isEmpty
                      ? 'No traders registered yet'
                      : 'No traders match your search',
                  subtitle: _all.isEmpty
                      ? 'Trader cards are published by real buyers in your area. Be the first to register and get found by farmers.'
                      : 'Try a different crop or clear the search.',
                  actionLabel: _all.isEmpty
                      ? 'Register as a trader'
                      : 'Clear search',
                  onAction: _all.isEmpty
                      ? _registerAsTrader
                      : () {
                          _search.clear();
                          setState(() => _filter = 'All');
                        },
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _TraderCard(
                      trader: _filtered[index],
                      onCall: () => _contactTraders([_filtered[index]]),
                    ),
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
                child:
                    Text(trader.emoji, style: const TextStyle(fontSize: 26)),
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
                        if (trader.rating != null) ...[
                          const Icon(Icons.star,
                              size: 16, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 3),
                          Text(
                            trader.rating!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      trader.company.isNotEmpty
                          ? trader.company
                          : 'Independent buyer',
                      style: TextStyle(
                        fontSize: 13,
                        color: c.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (trader.location != null)
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 13, color: c.textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            trader.location!,
                            style: TextStyle(
                                fontSize: 12, color: c.textSecondary),
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
              '${trader.cropLabel}: ${trader.priceLabel}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.primaryDark,
              ),
            ),
          ),
          if (trader.note != null && trader.note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              trader.note!,
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTonalButton(
                  label: trader.available ? 'Call now' : 'Currently busy',
                  icon: trader.available
                      ? Icons.call_outlined
                      : Icons.hourglass_empty,
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

class _TraderCardForm extends StatefulWidget {
  final VoidCallback onDone;
  const _TraderCardForm({required this.onDone});

  @override
  State<_TraderCardForm> createState() => _TraderCardFormState();
}

class _TraderCardFormState extends State<_TraderCardForm> {
  final ListingsService _service = ListingsService();
  final TextEditingController _company = TextEditingController();
  final TextEditingController _crops = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _company.dispose();
    _crops.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final crops = _crops.text
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    final price = double.tryParse(_price.text.trim());
    if (crops.isEmpty) {
      setState(() => _error = 'List at least one crop you buy');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.saveTraderOffer(
        company: _company.text.trim(),
        crops: crops,
        offeredPricePerQuintal: price,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      widget.onDone();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your buying card',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Farmers in your area will see this on the Traders tab.',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Text(_error!, style: TextStyle(color: c.danger, fontSize: 13)),
          const SizedBox(height: 10),
          TextField(
            controller: _crops,
            style: TextStyle(color: c.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Crops you buy *',
              hintText: 'e.g. Onion, Tomato, Rice',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _price,
            style: TextStyle(color: c.textPrimary),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Offering per quintal (\u20B9)',
              hintText: 'e.g. 4400',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _company,
            style: TextStyle(color: c.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Company / shop name',
              hintText: 'Optional',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            style: TextStyle(color: c.textPrimary),
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'A line for farmers (optional)',
              hintText: 'e.g. Paying cash at mandi gate',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppTonalButton(
                  label: 'Cancel',
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppPrimaryButton(
                  label: _saving ? 'Publishing\u2026' : 'Publish card',
                  icon: Icons.check,
                  onPressed: _saving ? null : _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}