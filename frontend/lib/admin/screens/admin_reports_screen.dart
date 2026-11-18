import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../admin_api.dart';
import '../admin_models.dart';
import '../admin_strings.dart';
import '../admin_theme.dart';
import '../widgets/admin_components.dart';
import '../widgets/admin_states.dart';

/// Screen 4.7 - Reports.
/// 
/// Server-computed aggregates. Export downloads CSV via the export endpoint.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  static const _ranges = <String, int>{'7d': 7, '30d': 30, '365': 365};

  int _days = 30;

  bool _loading = true;
  bool _authFailed = false;
  String? _error;
  AdminReportSummary? _summary;
  List<AdminCount> _activity = [];
  List<AdminCount> _crops = [];

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
    });
    try {
      final s = await AdminApi.instance.reportSummary(days: _days);
      final a = await AdminApi.instance.reportActivity(days: _days);
      final c = await AdminApi.instance.reportCrops(days: _days);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _activity = a;
        _crops = c;
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

  Future<void> _export(String kind) async {
    try {
      final csv = await AdminApi.instance.reportExportCsv(kind: kind, days: _days);
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV copied to clipboard ($kind, $_days days)')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed')),
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
            title: AdminStrings.of(AK.navReports),
            actions: [
              PopupMenuButton<String>(
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'summary', child: Text('Export summary')),
                  PopupMenuItem(value: 'activity', child: Text('Export activity')),
                  PopupMenuItem(value: 'crops', child: Text('Export crops')),
                ],
                onSelected: _export,
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(AdminStrings.of(AK.export)),
                ),
              ),
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
                    label: Text('${e.key}'),
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
    final s = _summary;
    if (s == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        _kpiRow(s),
        const SizedBox(height: 12),
        _twoCol(
          'Activity (top event types)',
          _listPanel(_activity),
          'Crops (top by listings)',
          _listPanel(_crops),
        ),
      ],
    );
  }

  Widget _kpiRow(AdminReportSummary s) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _kpi('Users total', s.usersTotal.toString(), AdminColors.primary),
        _kpi('Users new', s.usersNew.toString(), AdminColors.info),
        _kpi('Events', s.eventsInPeriod.toString(), AdminColors.warning),
        _kpi('Crops active', s.cropsActive.toString(), AdminColors.success),
        _kpi('Market listings', s.marketplaceTotal.toString(), AdminColors.purple),
        _kpi('Notifications', s.notificationsSent.toString(), AdminColors.mint),
      ],
    );
  }

  Widget _kpi(String label, String v, Color c) {
    return SizedBox(
      width: 190,
      child: AdminPanel(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11.5, color: AdminColors.textMuted)),
            const SizedBox(height: 4),
            Text(
              v,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AdminColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _twoCol(String t1, Widget w1, String t2, Widget w2) {
    return LayoutBuilder(
      builder: (ctx, c) {
        if (c.maxWidth < 760) {
          return Column(
            children: [
              AdminPanel(title: t1, child: w1),
              const SizedBox(height: 10),
              AdminPanel(title: t2, child: w2),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: AdminPanel(title: t1, child: w1)),
            const SizedBox(width: 10),
            Expanded(child: AdminPanel(title: t2, child: w2)),
          ],
        );
      },
    );
  }

  Widget _listPanel(List<AdminCount> items) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'No data',
          style: TextStyle(color: AdminColors.textMuted, fontSize: 12.5),
        ),
      );
    }
    return Column(
      children: [
        for (final x in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    x.label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ),
                AdminBadge(text: x.count.toString(), color: AdminColors.info),
              ],
            ),
          ),
      ],
    );
  }
}