import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_models.dart';
import '../admin_strings.dart';
import '../admin_theme.dart';
import '../widgets/admin_components.dart';
import '../widgets/admin_states.dart';

/// Screen 4.6 - Market Management.
/// 
/// Review market price rows, verify/unverify sources, view sources and forecast.
class AdminMarketScreen extends StatefulWidget {
  const AdminMarketScreen({super.key});

  @override
  State<AdminMarketScreen> createState() => _AdminMarketScreenState();
}

class _AdminMarketScreenState extends State<AdminMarketScreen> {
  final _commodity = TextEditingController();
  final _market = TextEditingController();
  final _state = TextEditingController();

  String _status = 'all';
  int _offset = 0;
  static const _size = 50;

  bool _loading = true;
  bool _authFailed = false;
  String? _error;
  AdminMarketPricePage? _page;
  List<AdminMarketSource> _sources = [];
  AdminForecast? _forecast;
  String _forecastKey = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _commodity.dispose();
    _market.dispose();
    _state.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadPrices(), _loadSources(), _loadForecast()]);
  }

  Future<void> _loadPrices() async {
    setState(() {
      _loading = true;
      _error = null;
      _authFailed = false;
    });
    try {
      bool? v;
      if (_status == 'verified') v = true;
      if (_status == 'unverified') v = false;
      final p = await AdminApi.instance.marketPrices(
        commodity: _commodity.text.trim().isEmpty ? null : _commodity.text.trim(),
        market: _market.text.trim().isEmpty ? null : _market.text.trim(),
        state: _state.text.trim().isEmpty ? null : _state.text.trim(),
        verified: v,
        limit: _size,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _page = p;
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

  Future<void> _loadSources() async {
    try {
      final s = await AdminApi.instance.marketSources();
      if (!mounted) return;
      setState(() => _sources = s);
    } catch (_) {}
  }

  Future<void> _loadForecast() async {
    final key = _commodity.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _forecastKey = key;
      _forecast = null;
    });
    try {
      final f = await AdminApi.instance.marketForecast(
        key,
        state: _state.text.trim().isEmpty ? null : _state.text.trim(),
        horizon: 7,
      );
      if (!mounted || _forecastKey != key) return;
      setState(() => _forecast = f);
    } catch (_) {}
  }

  Future<void> _toggleVerify(AdminMarketPrice p) async {
    try {
      if (p.sourceVerified) {
        await AdminApi.instance.unverifyMarketPrice(p.id);
      } else {
        await AdminApi.instance.verifyMarketPrice(p.id);
      }
      await _loadPrices();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update verification')),
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
        _pager(),
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
            title: AdminStrings.of(AK.navMarket),
            subtitle: _loading
                ? AdminStrings.of(AK.loading)
                : '${_page?.total ?? 0} price rows',
            actions: [
              IconButton(
                tooltip: AdminStrings.of(AK.refresh),
                onPressed: _loading ? null : _loadAll,
                icon: const Icon(Icons.refresh),
                style: IconButton.styleFrom(
                  backgroundColor: AdminColors.panel,
                  side: const BorderSide(color: AdminColors.border),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _commodity,
                  onSubmitted: (_) => _loadAll(),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(hintText: 'Commodity'),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _market,
                  onSubmitted: (_) => _loadPrices(),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(hintText: 'Market'),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _state,
                  onSubmitted: (_) => _loadAll(),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(hintText: 'State'),
                ),
              ),
              for (final s in const ['all', 'verified', 'unverified'])
                ChoiceChip(
                  selected: _status == s,
                  label: Text(s),
                  onSelected: (_) {
                    setState(() {
                      _status = s;
                      _offset = 0;
                    });
                    _loadPrices();
                  },
                ),
              TextButton(
                onPressed: () {
                  _commodity.clear();
                  _market.clear();
                  _state.clear();
                  _status = 'all';
                  _offset = 0;
                  _loadAll();
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          if (_sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            _sourcesPanel(),
          ],
          if (_forecast != null && _forecastKey.isNotEmpty) ...[
            const SizedBox(height: 10),
            _forecastPanel(),
          ],
        ],
      ),
    );
  }

  Widget _sourcesPanel() {
    return AdminPanel(
      title: 'Sources',
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final s in _sources.take(10))
            AdminBadge(
              text:
                  '${s.sourceName}: ${s.rows} rows (${s.verifiedRows} verified)',
              color: s.verifiedRows > 0 ? AdminColors.success : AdminColors.textMuted,
            ),
        ],
      ),
    );
  }

  Widget _forecastPanel() {
    final f = _forecast!;
    return AdminPanel(
      title: 'Forecast (derived, ${f.horizonDays}d) · basis ${f.basisPoints}',
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (f.status == 'insufficient_data')
            Text(
              f.reason ?? 'Insufficient observations (<3).',
              style: const TextStyle(color: AdminColors.warning, fontSize: 12.5),
            )
          else ...[
            Text(
              'Slope: ${f.slopePerDay} /day | Last: ₹${f.lastValue?.toStringAsFixed(0) ?? '—'}',
              style: const TextStyle(color: AdminColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final p in f.projection.take(5))
                  AdminBadge(
                    text:
                        '${p.date?.toIso8601String().split('T')[0] ?? ''}: ₹${p.value.toStringAsFixed(0)}',
                    color: AdminColors.info,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _body() {
    if (_authFailed) return adminNoAccessView();
    if (_loading) return const AdminLoading();
    if (_error != null) return adminErrorView(_loadPrices);
    final items = _page?.items ?? const [];
    if (items.isEmpty) {
      return adminEmptyView(
        icon: Icons.storefront_outlined,
        body: 'No price rows match the current filters.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _priceCard(items[i]),
    );
  }

  Widget _priceCard(AdminMarketPrice p) {
    return AdminPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AdminColors.panelAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.price_check_outlined, size: 18),
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
                        '${p.commodity} · ${p.market}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      p.tradeDate == null
                          ? ''
                          : p.tradeDate!.toIso8601String().split('T')[0],
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (p.modalPrice != null)
                      AdminBadge(
                        text: 'Modal: ₹${p.modalPrice!.toStringAsFixed(0)}',
                        color: AdminColors.primary,
                      ),
                    if (p.minPrice != null)
                      AdminBadge(
                        text: 'Min: ₹${p.minPrice!.toStringAsFixed(0)}',
                        color: AdminColors.info,
                      ),
                    if (p.maxPrice != null)
                      AdminBadge(
                        text: 'Max: ₹${p.maxPrice!.toStringAsFixed(0)}',
                        color: AdminColors.purple,
                      ),
                    if (p.state != null)
                      AdminBadge(text: p.state!, color: AdminColors.mint),
                    AdminBadge(
                      text: p.sourceName,
                      color: AdminColors.textMuted,
                    ),
                    AdminBadge(
                      text: p.sourceVerified ? 'Verified' : 'Unverified',
                      color: p.sourceVerified ? AdminColors.success : AdminColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              p.sourceVerified ? Icons.verified : Icons.verified_outlined,
              size: 18,
            ),
            onPressed: () => _toggleVerify(p),
            tooltip: p.sourceVerified ? 'Unverify' : 'Verify',
          ),
        ],
      ),
    );
  }

  Widget _pager() {
    final page = _page;
    if (page == null || page.items.isEmpty) return const SizedBox.shrink();
    final from = page.offset + 1;
    final to = page.offset + page.items.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          Text(
            'Showing $from–$to of ${page.total}',
            style: const TextStyle(fontSize: 12.5, color: AdminColors.textMuted),
          ),
          const Spacer(),
          IconButton(
            onPressed: page.offset > 0 && !_loading
                ? () {
                    setState(() => _offset = (page.offset - _size).clamp(0, 1 << 31));
                    _loadPrices();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: page.hasMore && !_loading
                ? () {
                    setState(() => _offset = page.offset + _size);
                    _loadPrices();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}