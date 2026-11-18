import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_models.dart';
import '../admin_strings.dart';
import '../admin_theme.dart';
import '../widgets/admin_components.dart';
import '../widgets/admin_states.dart';

/// Screen 4.5 - Crop Analytics.
/// 
/// Derived from real listings and market rows via `/admin/analytics/crops`.
class AdminCropAnalyticsScreen extends StatefulWidget {
  const AdminCropAnalyticsScreen({super.key});

  @override
  State<AdminCropAnalyticsScreen> createState() =>
      _AdminCropAnalyticsScreenState();
}

class _AdminCropAnalyticsScreenState extends State<AdminCropAnalyticsScreen> {
  static const _ranges = <String, int>{'30': 30, '90': 90, '365': 365};

  int _days = 90;

  bool _loading = true;
  bool _authFailed = false;
  String? _error;
  AdminCropAnalytics? _data;
  AdminCropDetail? _detail;
  String? _detailKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _authFailed = false;
      _detail = null;
      _detailKey = null;
    });
    try {
      final d = await AdminApi.instance.cropAnalytics(days: _days);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } on AdminAuthException {
      if (!mounted) return;
      setState(() {
        _authFailed = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AdminStrings.of(AK.errorBody);
        _loading = false;
      });
    }
  }

  Future<void> _showDetail(String commodity) async {
    setState(() {
      _detailKey = commodity;
      _detail = null;
    });
    try {
      final d = await AdminApi.instance.cropDetail(commodity);
      if (!mounted || _detailKey != commodity) return;
      setState(() => _detail = d);
    } catch (_) {
      if (mounted && _detailKey == commodity) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load detail')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _filters(),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: AdminStrings.of(AK.navCrops),
            subtitle: _loading
                ? AdminStrings.of(AK.loading)
                : '${_data?.crops.length ?? 0} crops',
            actions: [
              IconButton(
                tooltip: AdminStrings.of(AK.refresh),
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                style: IconButton.styleFrom(
                  backgroundColor: AdminColors.panel,
                  side: const BorderSide(color: AdminColors.border),
                ),
              ),
            ],
          ),
          Row(
            children: [
              for (final e in _ranges.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    selected: _days == e.value,
                    label: Text('${e.key}d'),
                    onSelected: (_) {
                      setState(() => _days = e.value);
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_authFailed) return adminNoAccessView();
    if (_loading) return const AdminLoading();
    if (_error != null) return adminErrorView(_load);
    final crops = _data?.crops ?? const [];
    if (crops.isEmpty) {
      return adminEmptyView(
        icon: Icons.insights_outlined,
        body: 'No crop data for this period.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: crops.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = crops[i];
        final showDetail = _detailKey == c.commodity;
        return Column(
          children: [
            _cropCard(c, showDetail),
            if (showDetail) _detailCard(),
          ],
        );
      },
    );
  }

  Widget _cropCard(AdminCropStat c, bool expanded) {
    return AdminPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.commodity,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                ),
                onPressed: () {
                  if (expanded) {
                    setState(() {
                      _detailKey = null;
                      _detail = null;
                    });
                  } else {
                    _showDetail(c.commodity);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              AdminBadge(text: '${c.listings} listings', color: AdminColors.info),
              AdminBadge(
                text: '${c.activeListings} active',
                color: AdminColors.success,
              ),
              AdminBadge(
                text: 'Qty: ${c.totalQuantity.toStringAsFixed(1)}',
                color: AdminColors.mint,
              ),
              if (c.avgExpectedPrice != null)
                AdminBadge(
                  text: 'Avg exp: ₹${c.avgExpectedPrice!.toStringAsFixed(0)}',
                  color: AdminColors.warning,
                ),
              if (c.latestModalPrice != null)
                AdminBadge(
                  text: 'Modal: ₹${c.latestModalPrice!.toStringAsFixed(0)}',
                  color: AdminColors.purple,
                ),
              AdminBadge(
                text: 'Market rows: ${c.marketRows}',
                color: AdminColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailCard() {
    final d = _detail;
    if (d == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdminColors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminColors.border),
          ),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.border),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            AdminBadge(text: 'Sold: ${d.soldListings}', color: AdminColors.danger),
            AdminBadge(text: 'Markets: ${d.distinctMarkets}', color: AdminColors.info),
            if (d.latestTradeDate != null)
              AdminBadge(
                text: 'Last trade: ${d.latestTradeDate!.toIso8601String().split('T')[0]}',
                color: AdminColors.mint,
              ),
            if (d.states.isNotEmpty)
              AdminBadge(text: 'States: ${d.states.join(',')}', color: AdminColors.textMuted),
          ],
        ),
      ),
    );
  }
}