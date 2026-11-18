import 'package:flutter/material.dart';

import 'package:jeevandhara2/app/destinations.dart';
import 'package:jeevandhara2/app/shell/app_shell.dart';
import 'package:jeevandhara2/models/trader.dart';
import 'package:jeevandhara2/models/user.dart';
import 'package:jeevandhara2/services/api_service.dart';
import 'package:jeevandhara2/services/listings_service.dart';
import 'package:jeevandhara2/services/trader_offer_store.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/widgets/ui/app_input.dart';
import 'package:jeevandhara2/widgets/ui/buttons.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';
import 'package:jeevandhara2/widgets/ui/states.dart';

/// The trader's entry point.
///
/// Like [HomeScreen] this is now a thin wrapper over [AppShell]: the overview
/// is the trader's landing destination and the sidebar carries the rest. The
/// overview survives as [TraderOverviewPage].
class TraderDashboardScreen extends StatelessWidget {
  const TraderDashboardScreen({super.key, this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) => AppShell(
        role: AppRole.trader,
        initialDestination: AppDestination.dashboard,
        initialUser: user,
      );
}

/// The trader's overview, read from `/traders/me`.
///
/// There is no deals feed behind it, so the page does not show one. What it
/// shows is the trader's own buying card — the only row the backend actually
/// stores for them — and says plainly when no card exists yet.
class TraderOverviewPage extends StatefulWidget {
  /// Injectable for tests; a real run uses the default HTTP client.
  final ListingsService? service;

  const TraderOverviewPage({super.key, this.service});

  @override
  State<TraderOverviewPage> createState() => _TraderOverviewPageState();
}

class _TraderOverviewPageState extends State<TraderOverviewPage> {
  late final ListingsService _service = widget.service ?? ListingsService();

  Trader? _offer;
  bool _loading = true;
  String? _error;
  String _name = '';

  @override
  void initState() {
    super.initState();
    TraderOfferStore.instance.addListener(_syncFromStore);
    if (TraderOfferStore.instance.hasLoaded) {
      _offer = TraderOfferStore.instance.offer;
      _loading = false;
    }
    _reload();
    _loadName();
  }

  @override
  void dispose() {
    TraderOfferStore.instance.removeListener(_syncFromStore);
    super.dispose();
  }

  void _syncFromStore() {
    if (!mounted) return;
    setState(() {
      _offer = TraderOfferStore.instance.offer;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _loadName() async {
    try {
      final user = await ApiService().getCurrentUser();
      if (!mounted) return;
      setState(() => _name = user.name.trim());
    } on Exception {
      // Signed out or offline; the greeting simply omits the name.
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = !TraderOfferStore.instance.hasLoaded;
      _error = null;
    });
    try {
      final offer = await _service.myOffer();
      if (!mounted) return;
      if (offer == null) {
        TraderOfferStore.instance.clear();
      } else {
        TraderOfferStore.instance.set(offer);
      }
      setState(() {
        _offer = offer;
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

  void _openPostOffer() {
    AppShellScope.maybeOf(context)?.open(AppDestination.postOffer);
  }

  Future<void> _takeDown() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take your card down?'),
        content: const Text(
          'Farmers will stop seeing your buying card. The card is kept '
          'server-side so your history is not lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Take down'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteTraderOffer();
      TraderOfferStore.instance.clear();
      if (!mounted) return;
      _snack('Your card is no longer shown to farmers.');
    } on Exception catch (e) {
      if (mounted) _snack(e.toString(), error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? context.colors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final first = _name.isEmpty ? null : _name.split(' ').first;

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
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
                        first == null
                            ? 'Good ${_greeting(context)}'
                            : 'Good ${_greeting(context)}, $first',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your buying card, and the crops you are ready to buy.',
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
                  child: const Icon(Icons.storefront,
                      color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(
            title: 'Your buying card',
            actionLabel: _offer == null ? 'Post Offer' : 'Edit Offer',
            actionIcon: _offer == null ? Icons.add : Icons.edit_outlined,
            onAction: _openPostOffer,
          ),
          const SizedBox(height: 10),
          _offerBody(context),
        ],
      ),
    );
  }

  Widget _offerBody(BuildContext context) {
    final c = context.colors;
    if (_loading) {
      return const AppCard(child: LoadingSkeleton(rows: 2));
    }
    if (_error != null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_off_outlined,
                    size: 20, color: c.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Could not load your buying card',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _reload, child: const Text('Try again')),
          ],
        ),
      );
    }

    final offer = _offer;
    if (offer == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge_outlined, size: 20, color: c.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No buying offer yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Publish a card so farmers growing your crops can find you. '
              'Your crop list and price are your own claim — the app does not '
              'verify them and does not invent a rating.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.4, color: c.textSecondary),
            ),
            const SizedBox(height: 14),
            AppPrimaryButton(
              label: 'Post an offer',
              icon: Icons.add_business_outlined,
              height: 46,
              onPressed: _openPostOffer,
            ),
          ],
        ),
      );
    }

    return _MyOfferCard(
      trader: offer,
      onEdit: _openPostOffer,
      onTakeDown: _takeDown,
    );
  }

  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

/// The trader's own card, rendered from the server row.
class _MyOfferCard extends StatelessWidget {
  final Trader trader;
  final VoidCallback onEdit;
  final VoidCallback onTakeDown;

  const _MyOfferCard({
    required this.trader,
    required this.onEdit,
    required this.onTakeDown,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final statusColor = trader.available ? c.positive : c.textSecondary;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: c.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child:
                      Text(trader.emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trader.company.isEmpty ? trader.name : trader.company,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      trader.location == null || trader.location!.isEmpty
                          ? trader.name
                          : '${trader.name} \u2022 ${trader.location}',
                      style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                text: trader.available ? 'Accepting offers' : 'Paused',
                color: statusColor,
                icon: trader.available
                    ? Icons.check_circle_outline
                    : Icons.pause_circle_outline,
              ),
              PopupMenuButton<String>(
                tooltip: 'Card actions',
                icon: Icon(Icons.more_vert, size: 18, color: c.textSecondary),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'takeDown') onTakeDown();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit offer')),
                  PopupMenuItem(value: 'takeDown', child: Text('Take down')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OfferFact(
                  label: 'Offers per quintal',
                  value: trader.priceLabel,
                  emphasise: trader.offeredPricePerQuintal != null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OfferFact(
                  label: 'Crops',
                  value: trader.crops.isEmpty
                      ? 'Not specified'
                      : trader.crops.join(', '),
                ),
              ),
            ],
          ),
          if (trader.note != null && trader.note!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              trader.note!,
              style: TextStyle(
                  fontSize: 12.5, height: 1.4, color: c.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Farmers see exactly this. The price is your claim and is not a '
            'mandi quote.',
            style: TextStyle(fontSize: 11.5, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _OfferFact extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;

  const _OfferFact({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: emphasise ? c.primaryDark : c.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Publish or edit the caller's "I am buying" card, backed by
/// `POST /traders/me`.
class TraderPostOfferPage extends StatefulWidget {
  /// Injectable for tests; a real run uses the default HTTP client.
  final ListingsService? service;

  const TraderPostOfferPage({super.key, this.service});

  @override
  State<TraderPostOfferPage> createState() => _TraderPostOfferPageState();
}

class _TraderPostOfferPageState extends State<TraderPostOfferPage> {
  late final ListingsService _service = widget.service ?? ListingsService();

  final _company = TextEditingController();
  final _crops = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();

  bool _available = true;
  bool _editing = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cached = TraderOfferStore.instance.offer;
    if (cached != null) {
      _fill(cached);
      _loading = false;
    }
    _loadExisting();
  }

  @override
  void dispose() {
    _company.dispose();
    _crops.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  void _fill(Trader trader) {
    _company.text = trader.company;
    _crops.text = trader.crops.join(', ');
    _price.text = trader.offeredPricePerQuintal == null
        ? ''
        : _number(trader.offeredPricePerQuintal!);
    _note.text = trader.note ?? '';
    _available = trader.available;
    _editing = true;
  }

  Future<void> _loadExisting() async {
    try {
      final offer = await _service.myOffer();
      if (!mounted) return;
      if (offer != null) {
        _fill(offer);
        TraderOfferStore.instance.set(offer);
      }
    } on Exception {
      // Prefill is best-effort. Submitting reports its own error, and a blank
      // form is still usable by someone who has no card yet.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final crops = _crops.text
        .split(',')
        .map((crop) => crop.trim())
        .where((crop) => crop.isNotEmpty)
        .toList();
    if (crops.isEmpty) {
      setState(() => _error = 'List at least one crop you buy.');
      return;
    }

    final priceText = _price.text.trim();
    final price = priceText.isEmpty ? null : double.tryParse(priceText);
    if (priceText.isNotEmpty && (price == null || price <= 0)) {
      setState(
          () => _error = 'Enter a price greater than 0, or leave it blank.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final saved = await _service.saveTraderOffer(
        company: _company.text.trim(),
        crops: crops,
        offeredPricePerQuintal: price,
        note: _note.text.trim(),
        available: _available,
      );
      if (!mounted) return;
      TraderOfferStore.instance.set(saved);
      setState(() {
        _saving = false;
        _editing = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your buying card is live. Farmers can now find you.'),
        ),
      );
      AppShellScope.maybeOf(context)?.open(AppDestination.dashboard);
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
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingSkeleton(rows: 3),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editing ? 'Edit your buying card' : 'New buying offer',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Farmers see exactly what you enter here. Your crops and price '
                'are your own claim; the app does not verify them.',
                style: TextStyle(
                    fontSize: 13, height: 1.4, color: c.textSecondary),
              ),
              const SizedBox(height: 18),
              AppTextField(
                controller: _crops,
                label: 'Crops you buy',
                icon: Icons.eco_outlined,
                hint: 'e.g. Onion, Tomato, Rice',
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _price,
                label: 'Offered price per quintal',
                icon: Icons.currency_rupee,
                hint: 'Optional — blank means "Price on call"',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _company,
                label: 'Company / shop name',
                icon: Icons.storefront_outlined,
                hint: 'Optional',
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _note,
                label: 'A line for farmers',
                icon: Icons.notes,
                hint: 'e.g. Paying cash at mandi gate',
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Visible to farmers',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          'Paused cards stay in your account but stop '
                          'appearing in the public trader list.',
                          style:
                              TextStyle(fontSize: 12, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _available,
                    onChanged: (value) => setState(() => _available = value),
                    activeThumbColor: c.primary,
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12.5, color: c.danger),
                ),
              ],
              const SizedBox(height: 18),
              AppPrimaryButton(
                label: _saving
                    ? 'Saving\u2026'
                    : _editing
                        ? 'Save changes'
                        : 'Publish card',
                icon: Icons.send_outlined,
                loading: _saving,
                onPressed: _saving ? null : _submit,
              ),
              const SizedBox(height: 10),
              Text(
                'Nothing is matched automatically yet: this card is simply '
                'listed on the Traders tab.',
                style: TextStyle(fontSize: 11.5, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `4400.0` reads as `4400`, `4400.5` stays `4400.5`.
String _number(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';

/// The trader's deals destination.
///
/// The backend stores buying cards, not orders, so there is no deal history to
/// read. This page says that plainly instead of listing trades that never
/// happened.
class TraderDealsPage extends StatelessWidget {
  const TraderDealsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No deals yet',
      subtitle: 'There is no orders endpoint yet, so completed trades cannot '
          'be listed here. Your buying card lives on the dashboard.',
    );
  }
}
