import 'package:flutter/material.dart';
import '../models/crop.dart';
import '../theme/colors.dart';
import '../theme/locale.dart';
import '../widgets/ui/cards.dart';
import '../widgets/ui/states.dart';
import 'sell_crop_screen.dart';

class MyCropsScreen extends StatefulWidget {
  const MyCropsScreen({super.key});

  @override
  State<MyCropsScreen> createState() => _MyCropsScreenState();
}

class _MyCropsScreenState extends State<MyCropsScreen> {
  final List<CropListing> _crops = CropListing.sampleData();
  bool _isLoading = false;
  bool _showEmptyUntilRestore = false;

  Future<void> _openSell() async {
    setState(() => _isLoading = true);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellCropScreen(onPosted: (crop) {
          if (mounted) setState(() => _showEmptyUntilRestore = false);
        }),
      ),
    );
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                      '${_crops.length} ${_crops.length == 1 ? 'crop' : 'crops'} listed',
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
                onPressed: _isLoading ? null : _openSell,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Crop'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: LoadingSkeleton(),
                )
              : (_showEmptyUntilRestore || _crops.isEmpty)
                  ? EmptyState(
                      icon: Icons.eco_outlined,
                      title: 'No crops listed yet',
                      subtitle: 'List your first crop and start receiving offers from traders.',
                      actionLabel: 'List a crop',
                      onAction: _openSell,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _crops.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _CropCard(crop: _crops[index]),
                    ),
        ),
      ],
    );
  }
}

class _CropCard extends StatelessWidget {
  final CropListing crop;

  const _CropCard({required this.crop});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final statusColor = crop.status == 'Sold'
        ? c.primaryDark
        : crop.status == 'Offer received'
            ? c.accent
            : c.primary;
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
                child: Center(child: Text(crop.emoji, style: const TextStyle(fontSize: 26))),
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
                      '${crop.quantity} \u2022 ${crop.location}',
                      style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                text: crop.status,
                color: statusColor,
                icon: crop.status == 'Sold' ? Icons.check_circle_outline : null,
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
                    Text('Expected price', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                    Text(
                      crop.expectedPrice,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Listed', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                    Text(
                      crop.listedAgo,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.arrow_forward, size: 15, color: c.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}