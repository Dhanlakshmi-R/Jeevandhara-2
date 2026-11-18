import 'package:flutter/material.dart';

import 'package:jeevandhara2/design/provenance.dart';
import 'package:jeevandhara2/models/market_price.dart';
import 'package:jeevandhara2/services/market_service.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/theme/locale.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';
import 'package:jeevandhara2/widgets/ui/data_source_status.dart';
import 'package:jeevandhara2/widgets/ui/provenance_chip.dart';
import 'package:jeevandhara2/widgets/ui/states.dart';

/// Live mandi prices, read from `/market/prices`.
///
/// Everything on this screen is either a served row or a stated reason for
/// having no rows. There is no in-memory sample list any more: the previous
/// build showed six invented crops with invented trends, and the screen now
/// fails to an honest empty state instead - "sources are down", with each
/// source's reason, reads differently from "nobody quoted onion today".
class MarketPricesScreen extends StatefulWidget {
  final MarketService? service;

  const MarketPricesScreen({super.key, this.service});

  @override
  State<MarketPricesScreen> createState() => _MarketPricesScreenState();
}

class _MarketPricesScreenState extends State<MarketPricesScreen> {
  late final MarketService _service = widget.service ?? MarketService();

  final TextEditingController _search = TextEditingController();

  MarketStatus? _status;
  List<String> _crops = <String>[];
  String? _crop;
  String? _market;
  List<MarketPrice> _rows = <MarketPrice>[];
  List<String> _markets = <String>[];

  bool _loading = false;
  bool _statusLoading = true;
  String? _error;
  List<SourceAttempt> _attempts = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadStatus(), _loadCrops()]);
    if (_crop != null) await _loadPrices();
  }

  Future<void> _loadStatus() async {
    setState(() => _statusLoading = true);
    try {
      final status = await _service.status();
      if (!mounted) return;
      setState(() {
        _status = status;
        _statusLoading = false;
      });
    } catch (_) {
      // A status read failing must not block prices: the price call reports
      // its own outage better than the status call would.
      if (!mounted) return;
      setState(() => _statusLoading = false);
    }
  }

  /// Crop picker, straight from `/market/commodities`. Crops we hold rows for
  /// come first, so the first chip the farmer taps has something behind it.
  Future<void> _loadCrops() async {
    try {
      final items = await _service.commodities();
      if (!mounted) return;
      setState(() {
        _crops = [for (final i in items) i.commodity];
        _crop ??= _crops.isEmpty ? null : _crops.first;
      });
      if (_markets.isEmpty) await _loadMandis();
    } catch (_) {
      // Without the list the screen still works: the farmer can only reach
      // crops by chips the server hands us another way. We do not invent one.
    }
  }

  Future<void> _loadMandis() async {
    try {
      final rows = await _service.mandis();
      if (!mounted) return;
      setState(() => _markets = rows.map((m) => m.market).toList());
    } catch (_) {
      // The mandi picker is optional; a missing list degrades to filtering by
      // whatever markets the loaded rows actually contain.
    }
  }

  Future<void> _loadPrices() async {
    final crop = _crop;
    if (crop == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _attempts = const [];
    });
    try {
      final page = await _service.prices(commodity: crop);
      if (!mounted) return;
      final markets = <String>{
        for (final r in page.rows)
          if (r.market != null && r.market!.isNotEmpty) r.market!,
      };
      setState(() {
        _rows = page.rows;
        _markets = markets.toList()..sort();
        if (_market != null && !markets.contains(_market)) _market = null;
        _loading = false;
      });
    } on MarketUnavailableException catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        _error = e.message;
        _attempts = e.attempts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _reload() async {
    await Future.wait([_loadStatus(), _loadPrices()]);
  }

  List<MarketPrice> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _rows.where((p) {
      final haystack = [
        p.commodity,
        p.variety ?? '',
        p.market ?? '',
        p.district ?? '',
      ].join(' ').toLowerCase();
      final matchQ = q.isEmpty || haystack.contains(q);
      final matchM = _market == null || p.market == _market;
      return matchQ && matchM;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_statusLoading && _crop == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingSkeleton(rows: 5),
      );
    }

    return Column(
      children: [
        if (_status != null)
          DataSourceStatusBanner(
            status: _status!,
            implication: _rows.isEmpty && !_loading
                ? context.str(K.noRowsForCrop)
                : null,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: context.str(K.searchCrops),
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                icon: Icon(Icons.filter_list, color: c.primary),
                tooltip: context.str(K.filterFreshness),
                onSelected: (v) => setState(() => _freshnessFilter = v),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'All', child: Text(context.str(K.all))),
                  PopupMenuItem(
                      value: 'Fresh', child: Text(context.str(K.fresh))),
                  PopupMenuItem(
                      value: 'Stale', child: Text(context.str(K.stale))),
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
              if (_crops.isNotEmpty)
                for (final crop in _crops) ...[
                  _MarketChip(
                    label: crop,
                    selected: _crop == crop,
                    onTap: () => setState(() {
                      _crop = crop;
                      _market = null;
                      _loadPrices();
                    }),
                  ),
                  const SizedBox(width: 8),
                ]
              else if (_markets.isNotEmpty)
                for (final m in _markets) ...[
                  _MarketChip(
                    label: m,
                    selected: _market == m,
                    onTap: () => setState(() {
                      _market = _market == m ? null : m;
                    }),
                  ),
                  const SizedBox(width: 8),
                ],
            ],
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  String? _freshnessFilter;

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LoadingSkeleton(rows: 5),
      );
    }
    if (_error != null) {
      return _ErrorState(
        message: _error!,
        attempts: _attempts,
        onRetry: _loadPrices,
      );
    }
    if (_rows.isEmpty) {
      return EmptyState(
        icon: Icons.trending_up,
        title: context.str(K.noMarketData),
        subtitle: context.str(K.noMarketDataHint),
      );
    }

    final shown = _filtered.where((p) {
      if (_freshnessFilter == 'Fresh') {
        return p.provenance.freshness == Freshness.fresh;
      }
      if (_freshnessFilter == 'Stale') {
        return p.provenance.freshness == Freshness.stale;
      }
      return true;
    }).toList();

    if (shown.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: context.str(K.noCropsFound),
        subtitle: context.str(K.noCropsFoundHint),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          FreshnessBanner(
            rows: [for (final r in shown) r.provenance],
            implication: context.str(K.staleWindowHint),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final row in shown) ...[
                  _PriceRowCard(row: row),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MarketChip(
      {required this.label, required this.selected, required this.onTap});

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

/// Failure with reasons: the per-source `attempts` block is the whole point,
/// so it is rendered line by line instead of behind a "try again".
class _ErrorState extends StatelessWidget {
  final String message;
  final List<SourceAttempt> attempts;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.attempts,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: c.warning),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            if (attempts.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final a in attempts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${a.source}: ${a.reason}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: onRetry,
                child: Text(context.str(K.tryAgainNow)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One quotation. The number, then immediately where it came from and how old
/// it is - provenance is attached to the row rather than collected in a
/// footnote, because a footnote is what gets scrolled past.
class _PriceRowCard extends StatelessWidget {
  final MarketPrice row;

  const _PriceRowCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = row.provenance;
    final actionable = p.actionable;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.commodity,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (row.market != null) row.market!,
                        if (row.district != null) row.district!,
                        if (row.variety != null) row.variety!,
                      ].join(' \u2022 '),
                      style:
                          TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    row.priceLabelOf(context.str),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: c.primaryDark,
                    ),
                  ),
                  if (row.rangeLabel != null)
                    Text(
                      '${row.rangeLabel!} ${context.str(K.rangeSuffix)}',
                      style:
                          TextStyle(fontSize: 11, color: c.textSecondary),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ProvenanceChip(provenance: p),
              FreshnessBadge(provenance: p),
              Text(
                row.observedLabelOf(context.str),
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
            ],
          ),
          if (row.arrivalQuantity != null) ...[
            const SizedBox(height: 8),
            Text(
              context
                  .str(K.arrivalsLabel)
                  .replaceFirst('{n}', '${row.arrivalQuantity} ${row.unit ?? ''}'),
              style: TextStyle(fontSize: 11.5, color: c.textSecondary),
            ),
          ],
          if (p.note != null) ...[
            const SizedBox(height: 6),
            Text(
              p.note!,
              style: TextStyle(fontSize: 11, height: 1.35, color: c.textSecondary),
            ),
          ],
          if (!actionable) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 15, color: c.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${context.str(K.tooOldToAct)} - '
                      '${context.str(K.tooOldToActHint)}',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
