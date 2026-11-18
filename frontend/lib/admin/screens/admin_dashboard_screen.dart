import 'package:flutter/material.dart';

import '../../theme/locale.dart';
import '../admin_api.dart';
import '../admin_models.dart';
import '../admin_sections.dart';
import '../admin_strings.dart';
import '../admin_theme.dart';
import '../widgets/admin_components.dart';
import '../widgets/admin_states.dart';

/// Screen 4.1 — the console landing view.
///
/// Reads only what the admin API returns: an overview, a daily series and the
/// most recent audit events. If those calls fail, it shows an error rather than
/// placeholder numbers, and if a series is empty it says so.
class AdminDashboardScreen extends StatefulWidget {
  final void Function(AdminSection section)? onOpenSection;

  const AdminDashboardScreen({super.key, this.onOpenSection});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const _ranges = <int>[7, 30, 90];

  int _days = 30;
  bool _loading = true;
  bool _authFailed = false;
  String? _error;
  DateTime? _updatedAt;

  AdminOverview? _overview;
  List<DailyStat> _stats = const [];
  List<AdminActivityEvent> _activity = const [];

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
      final results = await Future.wait([
        AdminApi.instance.overview(),
        AdminApi.instance.dailyStats(days: _days),
        AdminApi.instance.activity(limit: 8),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as AdminOverview;
        _stats = results[1] as List<DailyStat>;
        _activity = (results[2] as AdminActivityPage).events;
        _updatedAt = DateTime.now();
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

  int get _newThisPeriod =>
      _stats.fold<int>(0, (sum, s) => sum + s.signups);

  int get _eventsThisPeriod =>
      _stats.fold<int>(0, (sum, s) => sum + s.events);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AdminColors.primary,
      backgroundColor: AdminColors.panel,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AdminPageHeader(
            title: _greeting(),
            subtitle: _updatedAt == null
                ? null
                : AdminStrings.of(AK.lastUpdated, fallback: 'Updated {t}')
                    .replaceFirst('{t}', _timeAgo(_updatedAt!)),
            actions: [
              _rangeSelector(),
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
          if (_authFailed)
            adminNoAccessView()
          else if (_loading)
            const AdminLoading()
          else if (_error != null)
            adminErrorView(_load)
          else
            _body(),
        ],
      ),
    );
  }

  Widget _rangeSelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AdminColors.panel,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in _ranges)
            GestureDetector(
              onTap: _loading
                  ? null
                  : () {
                      if (_days == d) return;
                      setState(() => _days = d);
                      _load();
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _days == d ? AdminColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _rangeLabel(d),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _days == d
                        ? AdminColors.textOnPrimary
                        : AdminColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _rangeLabel(int d) {
    if (d == 7) return AdminStrings.of(AK.range7d);
    if (d == 30) return AdminStrings.of(AK.range30d);
    return AdminStrings.of(AK.range90d);
  }

  Widget _body() {
    final o = _overview!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kpiGrid(o),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth > 900;
          final chart = _growthPanel();
          final distribution = _distributionPanel(o);
          if (wide) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: chart),
                  const SizedBox(width: 18),
                  Expanded(flex: 2, child: distribution),
                ],
              ),
            );
          }
          return Column(
            children: [
              chart,
              const SizedBox(height: 18),
              distribution,
            ],
          );
        }),
        const SizedBox(height: 18),
        _recentActivityPanel(),
        const SizedBox(height: 18),
        _quickLinks(),
      ],
    );
  }

  Widget _kpiGrid(AdminOverview o) {
    final cards = <Widget>[
      AdminMetricCard(
        label: AdminStrings.of(AK.totalUsers),
        value: '${o.totalUsers}',
        icon: Icons.group_outlined,
        accent: AdminColors.primary,
      ),
      AdminMetricCard(
        label: AdminStrings.of(AK.activeUsers),
        value: '${o.activeUsers}',
        icon: Icons.verified_user_outlined,
        accent: AdminColors.success,
      ),
      AdminMetricCard(
        label: AdminStrings.of(AK.suspendedUsers),
        value: '${o.suspendedUsers}',
        icon: Icons.block_outlined,
        accent: AdminColors.danger,
      ),
      AdminMetricCard(
        label: AdminStrings.of(AK.newThisPeriod),
        value: '$_newThisPeriod',
        icon: Icons.person_add_alt_outlined,
        accent: AdminColors.info,
      ),
      AdminMetricCard(
        label: AdminStrings.of(AK.totalActivity),
        value: '$_eventsThisPeriod',
        icon: Icons.bolt_outlined,
        accent: AdminColors.warning,
      ),
      AdminMetricCard(
        label: AdminStrings.of(AK.activeUsers),
        value: '${o.activeSessions}',
        icon: Icons.devices_outlined,
        accent: AdminColors.teal,
        hint: AdminStrings.of(AK.users),
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 1180
          ? 6
          : c.maxWidth > 820
              ? 3
              : c.maxWidth > 520
                  ? 2
                  : 1;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: cols == 1 ? 3.4 : 1.55,
        children: cards,
      );
    });
  }

  Widget _growthPanel() {
    final bars = [
      for (final s in _stats)
        AdminBar(_shortDay(s.day), s.signups),
    ];
    return AdminPanel(
      title: AdminStrings.of(AK.userGrowth),
      subtitle: _rangeLabel(_days),
      child: bars.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 44),
              child: Center(
                child: Text(
                  AdminStrings.of(AK.noGrowth),
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          : AdminBarChart(bars: bars, height: 190),
    );
  }

  Widget _distributionPanel(AdminOverview o) {
    final total = o.totalUsers;
    return AdminPanel(
      title: AdminStrings.of(AK.roleDistribution),
      child: total <= 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  AdminStrings.of(AK.emptyBody),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                AdminDistributionBar(
                  label: AdminStrings.of(AK.roleFarmer),
                  value: o.farmers,
                  total: total,
                  color: AdminColors.primary,
                ),
                AdminDistributionBar(
                  label: AdminStrings.of(AK.roleTrader),
                  value: o.traders,
                  total: total,
                  color: AdminColors.info,
                ),
                AdminDistributionBar(
                  label: AdminStrings.of(AK.roleAdmin),
                  value: o.admins,
                  total: total,
                  color: AdminColors.warning,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: AdminColors.mint),
                    const SizedBox(width: 6),
                    Text(
                      '${o.activeUsers} ${AdminStrings.of(AK.active).toLowerCase()} · '
                      '${o.suspendedUsers} ${AdminStrings.of(AK.suspended).toLowerCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _recentActivityPanel() {
    return AdminPanel(
      title: AdminStrings.of(AK.recentActivity),
      dense: true,
      trailing: TextButton(
        onPressed: widget.onOpenSection == null
            ? null
            : () => widget.onOpenSection!(AdminSection.activity),
        child: Text(AdminStrings.of(AK.viewAll)),
      ),
      child: _activity.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text(
                  AdminStrings.of(AK.noActivity),
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < _activity.length; i++) ...[
                  _activityRow(_activity[i]),
                  if (i != _activity.length - 1)
                    const Divider(height: 18, color: AdminColors.divider),
                ],
              ],
            ),
    );
  }

  Widget _activityRow(AdminActivityEvent e) {
    final summary = _summaryFor(e);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _eventColor(e.eventType).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_eventIcon(e.eventType),
              size: 17, color: _eventColor(e.eventType)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${e.eventType} · ${_timeAgo(e.createdAt)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AdminColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickLinks() {
    final links = <AdminSection>[
      AdminSection.users,
      AdminSection.activity,
      AdminSection.weatherAlerts,
      AdminSection.market,
      AdminSection.reports,
      AdminSection.notifications,
    ];
    return AdminPanel(
      title: AdminStrings.of(AK.quickLinks),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final s in links)
            OutlinedButton.icon(
              onPressed: widget.onOpenSection == null
                  ? null
                  : () => widget.onOpenSection!(s),
              icon: Icon(s.icon, size: 17),
              label: Text(s.label),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminColors.textPrimary,
                side: const BorderSide(color: AdminColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- helpers

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return '${AdminStrings.of(AK.greetings)} 🌅';
    if (h < 17) return '${AdminStrings.of(AK.greetings)} ☀️';
    return '${AdminStrings.of(AK.greetings)} 🌙';
  }

  String _summaryFor(AdminActivityEvent e) {
    final local = LanguageController.instance.isKannada ? e.summaryKn : e.summaryEn;
    if (local != null && local.trim().isNotEmpty) return local;
    if (e.action != null && e.entityType != null) {
      return '${e.action} · ${e.entityType}';
    }
    return e.eventType;
  }

  String _shortDay(DateTime? d) {
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  IconData _eventIcon(String type) {
    if (type.contains('login')) return Icons.login;
    if (type.contains('logout')) return Icons.logout;
    if (type.contains('suspend')) return Icons.block;
    if (type.contains('register') || type.contains('created')) {
      return Icons.person_add_alt_1;
    }
    if (type.contains('session')) return Icons.devices;
    if (type.contains('view')) return Icons.visibility_outlined;
    if (type.contains('revoke')) return Icons.link_off;
    return Icons.bolt_outlined;
  }

  Color _eventColor(String type) {
    if (type.contains('suspend') || type.contains('revoke')) {
      return AdminColors.danger;
    }
    if (type.contains('login') || type.contains('register')) {
      return AdminColors.primary;
    }
    if (type.contains('view')) return AdminColors.info;
    return AdminColors.warning;
  }
}
