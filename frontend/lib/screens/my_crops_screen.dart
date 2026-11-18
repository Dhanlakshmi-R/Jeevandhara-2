import 'package:flutter/material.dart';

import 'package:jeevandhara2/models/crop.dart';
import 'package:jeevandhara2/services/crops_service.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/theme/locale.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';
import 'package:jeevandhara2/widgets/ui/states.dart';
import 'sell_crop_screen.dart';

/// The farmer's own listings, read from `/my-crops`.
///
/// The screen is a view over the server's rows: posting creates a real row,
/// marking sold PATCHes its status, and taking it down soft-deletes it. There
/// is no local sample list — an empty response is a real empty state, and a
/// failed read names the failure instead of looking like "no crops".
class MyCropsScreen extends StatefulWidget {
  final CropsService? service;

  const MyCropsScreen({super.key, this.service});

  @override
  State<MyCropsScreen> createState() => _MyCropsScreenState();
}

class _MyCropsScreenState extends State<MyCropsScreen> {
  late final CropsService _service = widget.service ?? CropsService();

  final List<CropListing> _crops = [];
  bool _loading = true;
  String? _error;

  /// Hidden rows are kept server-side for history but are not "listed" any
  /// more, so the screen does not show them.
  List<CropListing> get _visibleCrops =>
      _crops.where((crop) => !crop.isHidden).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = _crops.isEmpty;
      _error = null;
    });
    try {
      final crops = await _service.crops();
      if (!mounted) return;
      setState(() {
        _crops
          ..clear()
          ..addAll(crops);
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

  Future<void> _openSell() async {
    final created = await Navigator.of(context).push<CropListing>(
      MaterialPageRoute(builder: (_) => SellCropScreen(service: _service)),
    );
    if (created == null || !mounted) return;
    setState(() => _crops.insert(0, created));
  }

  Future<void> _openEdit(CropListing crop) async {
    final updated = await Navigator.of(context).push<CropListing>(
      MaterialPageRoute(
        builder: (_) => SellCropScreen(crop: crop, service: _service),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      final index = _crops.indexWhere((c) => c.id == updated.id);
      if (index >= 0) _crops[index] = updated;
    });
    _snack('${updated.name} updated.');
  }

  Future<void> _markSold(CropListing crop) async {
    try {
      final updated = await _service.setStatus(crop.id, 'sold');
      if (!mounted) return;
      setState(() {
        final index = _crops.indexWhere((c) => c.id == crop.id);
        if (index >= 0) _crops[index] = updated;
      });
      _snack('${crop.name} marked as sold.');
    } on Exception catch (e) {
      if (mounted) _snack(e.toString(), error: true);
    }
  }

  Future<void> _retire(CropListing crop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take this listing down?'),
        content: Text(
          '${crop.name} will stop being shown to traders. The row is kept '
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
      await _service.retire(crop.id);
      if (!mounted) return;
      setState(() => _crops.removeWhere((c) => c.id == crop.id));
      _snack('${crop.name} taken down.');
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
    final crops = _visibleCrops;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.str('myCrops'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      '${crops.length} ${crops.length == 1 ? 'crop' : 'crops'} listed',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : _openSell,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Crop'),
              ),
            ],
          ),
        ),
        Expanded(child: _body(crops)),
      ],
    );
  }

  Widget _body(List<CropListing> crops) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingSkeleton(),
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load your crops',
        subtitle: _error!,
        actionLabel: 'Try again',
        onAction: _reload,
      );
    }
    if (crops.isEmpty) {
      return EmptyState(
        icon: Icons.eco_outlined,
        title: 'No crops listed yet',
        subtitle:
            'List your first crop and start receiving offers from traders.',
        actionLabel: 'List a crop',
        onAction: _openSell,
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: crops.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _CropCard(
          crop: crops[index],
          onEdit: () => _openEdit(crops[index]),
          onMarkSold: () => _markSold(crops[index]),
          onRetire: () => _retire(crops[index]),
        ),
      ),
    );
  }
}

class _CropCard extends StatelessWidget {
  final CropListing crop;
  final VoidCallback onEdit;
  final VoidCallback onMarkSold;
  final VoidCallback onRetire;

  const _CropCard({
    required this.crop,
    required this.onEdit,
    required this.onMarkSold,
    required this.onRetire,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final statusColor = crop.isSold
        ? c.primaryDark
        : crop.isActive
            ? c.primary
            : c.textSecondary;

    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        Text(crop.emoji, style: const TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crop.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      '${crop.quantityLabel} \u2022 '
                      '${crop.location ?? 'Location not set'}',
                      style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                text: crop.statusLabel,
                color: statusColor,
                icon: crop.isSold ? Icons.check_circle_outline : null,
              ),
              PopupMenuButton<String>(
                tooltip: 'Listing actions',
                icon: Icon(Icons.more_vert, size: 18, color: c.textSecondary),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'sold') onMarkSold();
                  if (value == 'retire') onRetire();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  if (crop.isActive)
                    const PopupMenuItem(
                      value: 'sold',
                      child: Text('Mark as sold'),
                    ),
                  if (!crop.isHidden)
                    const PopupMenuItem(
                      value: 'retire',
                      child: Text('Take down'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expected price',
                        style: TextStyle(fontSize: 11, color: c.textSecondary)),
                    Text(
                      crop.priceLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: crop.expectedPrice == null
                            ? c.textSecondary
                            : c.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Listed',
                        style: TextStyle(fontSize: 11, color: c.textSecondary)),
                    Text(
                      crop.listedAgo(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
