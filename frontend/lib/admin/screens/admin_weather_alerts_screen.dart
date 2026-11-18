import 'dart:async';

import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_models.dart';
import '../admin_strings.dart';
import '../admin_theme.dart';
import '../widgets/admin_components.dart';
import '../widgets/admin_states.dart';
import '../../widgets/weather/weather_panel.dart';

/// Screen 4.4 - Weather & Alerts.
///
/// Two tabs: the live weather panel (the exact same widget farmers use, so an
/// operator sees what users see) and the operator-published advisories managed
/// via `/admin/weather-alerts`. The advisories list never invents alerts, and
/// its state is fully server-driven.
class AdminWeatherAlertsScreen extends StatefulWidget {
  const AdminWeatherAlertsScreen({super.key});

  @override
  State<AdminWeatherAlertsScreen> createState() =>
      _AdminWeatherAlertsScreenState();
}

class _AdminWeatherAlertsScreenState extends State<AdminWeatherAlertsScreen> {
  bool _activeOnly = false;
  String? _severity;
  Timer? _debounce;

  bool _loading = true;
  bool _authFailed = false;
  String? _error;
  List<AdminWeatherAlert> _alerts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _authFailed = false;
    });
    try {
      final items = await AdminApi.instance.weatherAlerts(
        activeOnly: _activeOnly,
        severity: _severity,
      );
      if (!mounted) return;
      setState(() {
        _alerts = items;
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

  Color _severityColor(String s) {
    switch (s) {
      case 'critical':
        return AdminColors.critical;
      case 'warning':
        return AdminColors.warning;
      case 'info':
      default:
        return AdminColors.info;
    }
  }

  IconData _scopeIcon(String s) {
    switch (s) {
      case 'state':
        return Icons.map_outlined;
      case 'district':
        return Icons.pin_drop_outlined;
      default:
        return Icons.public;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: AdminPageHeader(
              title: AdminStrings.of(AK.navWeather),
              subtitle: 'Live weather and operator advisories',
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AdminColors.primary,
              unselectedLabelColor: AdminColors.textSecondary,
              indicatorColor: AdminColors.primary,
              dividerColor: AdminColors.border,
              tabs: [
                Tab(
                  text: 'Live weather',
                  icon: Icon(Icons.wb_sunny_outlined, size: 18),
                ),
                Tab(
                  text: 'Advisories',
                  icon: Icon(Icons.warning_amber_outlined, size: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const WeatherPanel(),
                _advisoriesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _advisoriesTab() {
    return Column(
      children: [
        _advisoriesToolbar(),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _advisoriesToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  selected: _activeOnly,
                  label: const Text('Active only'),
                  onSelected: (v) {
                    setState(() => _activeOnly = v);
                    _load();
                  },
                  backgroundColor: AdminColors.panel,
                ),
                for (final s in const ['info', 'warning', 'critical'])
                  FilterChip(
                    selected: _severity == s,
                    label: Text(s),
                    onSelected: (v) {
                      setState(() => _severity = v ? s : null);
                      _load();
                    },
                    backgroundColor: AdminColors.panel,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: AdminStrings.of(AK.refresh),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            style: IconButton.styleFrom(
              backgroundColor: AdminColors.panel,
              side: const BorderSide(color: AdminColors.border),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _showEditor(null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New alert'),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_authFailed) return adminNoAccessView();
    if (_loading) return const AdminLoading();
    if (_error != null) return adminErrorView(_load);
    if (_alerts.isEmpty) {
      return adminEmptyView(
        icon: Icons.warning_amber_outlined,
        body: 'No weather alerts for this filter.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: _alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _card(_alerts[i]),
    );
  }

  Widget _card(AdminWeatherAlert a) {
    return AdminPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _severityColor(a.severity).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              a.severity == 'critical'
                  ? Icons.dangerous_outlined
                  : Icons.warning_amber_outlined,
              size: 20,
              color: _severityColor(a.severity),
            ),
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
                        a.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      a.createdAt == null ? '—' : a.createdAt!.toString(),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  a.messageEn,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AdminColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    AdminBadge(
                      text: a.severity,
                      color: _severityColor(a.severity),
                    ),
                    AdminBadge(
                      text: a.isActive ? 'Active' : 'Inactive',
                      color: a.isActive ? AdminColors.success : AdminColors.textMuted,
                    ),
                    AdminBadge(
                      icon: _scopeIcon(a.scopeType),
                      text: a.scopeType == 'all'
                          ? 'All'
                          : '${a.scopeType}${a.scopeValue != null ? ' · ${a.scopeValue}' : ''}',
                      color: AdminColors.mint,
                    ),
                    if (a.validFrom != null || a.validUntil != null)
                      AdminBadge(
                        icon: Icons.schedule_outlined,
                        text:
                            '${a.validFrom != null ? a.validFrom!.toIso8601String().split('T')[0] : '—'} → ${a.validUntil != null ? a.validUntil!.toIso8601String().split('T')[0] : '—'}',
                        color: AdminColors.info,
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'toggle', child: Text('Toggle active')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  _showEditor(a);
                  break;
                case 'toggle':
                  _toggle(a);
                  break;
                case 'delete':
                  _delete(a);
                  break;
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEditor(AdminWeatherAlert? a) {
    final title = TextEditingController(text: a?.title ?? '');
    final msgEn = TextEditingController(text: a?.messageEn ?? '');
    final msgKn = TextEditingController(text: a?.messageKn ?? '');
    String severity = a?.severity ?? 'info';
    String scopeType = a?.scopeType ?? 'all';
    final scopeValue = TextEditingController(text: a?.scopeValue ?? '');
    bool isActive = a?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(a == null ? 'New alert' : 'Edit alert'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: msgEn,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message (EN)'),
              ),
              TextField(
                controller: msgKn,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Message (KN, optional)'),
              ),
              DropdownButtonFormField<String>(
                value: severity,
                items: const ['info', 'warning', 'critical']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => severity = v ?? 'info',
                decoration: const InputDecoration(labelText: 'Severity'),
              ),
              DropdownButtonFormField<String>(
                value: scopeType,
                items: const ['all', 'state', 'district']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => scopeType = v ?? 'all',
                decoration: const InputDecoration(labelText: 'Scope'),
              ),
              if (scopeType != 'all')
                TextField(
                  controller: scopeValue,
                  decoration: InputDecoration(
                    labelText: scopeType == 'state' ? 'State' : 'District',
                  ),
                ),
              SwitchListTile(
                title: const Text('Active'),
                value: isActive,
                onChanged: (v) => isActive = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final payload = <String, dynamic>{
                'title': title.text.trim(),
                'message_en': msgEn.text.trim(),
                'severity': severity,
                'scope_type': scopeType,
                'is_active': isActive,
              };
              if (msgKn.text.trim().isNotEmpty) payload['message_kn'] = msgKn.text.trim();
              if (scopeType != 'all' && scopeValue.text.trim().isNotEmpty) {
                payload['scope_value'] = scopeValue.text.trim();
              }
              Navigator.pop(ctx);
              try {
                if (a == null) {
                  await AdminApi.instance.createWeatherAlert(payload);
                } else {
                  await AdminApi.instance.updateWeatherAlert(a.id, payload);
                }
                if (mounted) await _load();
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to save alert')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(AdminWeatherAlert a) async {
    try {
      await AdminApi.instance.updateWeatherAlert(a.id, {'is_active': !a.isActive});
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update alert')),
        );
      }
    }
  }

  Future<void> _delete(AdminWeatherAlert a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete alert'),
        content: Text('Remove "${a.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminApi.instance.deleteWeatherAlert(a.id);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete alert')),
        );
      }
    }
  }
}