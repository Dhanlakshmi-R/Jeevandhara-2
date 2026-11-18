import 'dart:async';

import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_models.dart';
import '../admin_nav.dart';
import '../admin_strings.dart';
import '../admin_theme.dart';
import '../widgets/admin_components.dart';
import '../widgets/admin_states.dart';

/// Activity Logs section — the full audit trail at `/admin/activity`.
///
/// Filters (event type, actor, time window) go straight to the server; the page
/// shows a page of rows and never aggregates or guesses event counts.
class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  static const _pageSize = 40;
  static const _ranges = <String, int?>{'Today': 0, '7d': 7, '30d': 30, 'All': null};

  final _eventController = TextEditingController();
  Timer? _debounce;

  String _range = '7d';
  String _eventType = '';
  int _offset = 0;

  bool _loading = true;
  bool _authFailed = false;
  String? _error;
  AdminActivityPage? _page;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _eventController.dispose();
    super.dispose();
  }

  DateTime? get _since {
    final days = _ranges[_range];
    if (days == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days == 0 ? 0 : days - 1));
  }

  void _onEventChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _eventType = value;
        _offset = 0;
      });
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _authFailed = false;
    });
    try {
      final page = await AdminApi.instance.activity(
        eventType: _eventType,
        since: _since,
        limit: _pageSize,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _page = page;
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
            title: AdminStrings.of(AK.navActivity),
            subtitle: _loading
                ? AdminStrings.of(AK.loading)
                : '${_page?.total ?? 0} events',
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
              Expanded(
                child: TextField(
                  controller: _eventController,
                  onChanged: _onEventChanged,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    hintText: 'Filter by event type (e.g. login_success)',
                    prefixIcon: Icon(Icons.filter_alt_outlined, size: 19),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _rangeSelector(),
            ],
          ),
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
          for (final entry in _ranges.entries)
            GestureDetector(
              onTap: () {
                if (_range == entry.key) return;
                setState(() {
                  _range = entry.key;
                  _offset = 0;
                });
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: _range == entry.key
                      ? AdminColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _range == entry.key
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

  Widget _body() {
    if (_authFailed) return adminNoAccessView();
    if (_loading && _page == null) return const AdminLoading();
    if (_error != null) return adminErrorView(_load);
    final events = _page?.events ?? const <AdminActivityEvent>[];
    if (events.isEmpty) {
      return adminEmptyView(
        icon: Icons.receipt_long_outlined,
        body: AdminStrings.of(AK.noActivity),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _eventCard(events[i]),
    );
  }

  Widget _eventCard(AdminActivityEvent e) {
    final summary = (e.summaryEn?.trim().isNotEmpty ?? false)
        ? e.summaryEn!
        : e.eventType;
    return AdminPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _eventColor(e.eventType).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_eventIcon(e.eventType),
                size: 18, color: _eventColor(e.eventType)),
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
                        summary,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      formatDateTime(e.createdAt),
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
                    AdminBadge(text: e.eventType, color: _eventColor(e.eventType)),
                    if (e.actorUserId != null)
                      AdminBadge(
                        text: 'actor #${e.actorUserId}'
                            '${e.actorRole != null ? ' · ${e.actorRole}' : ''}',
                        color: AdminColors.info,
                      ),
                    if (e.entityType != null)
                      AdminBadge(
                        text:
                            '${e.entityType}${e.entityId != null ? ' #${e.entityId}' : ''}',
                        color: AdminColors.mint,
                      ),
                    if (e.ipAddress != null)
                      AdminBadge(text: e.ipAddress!, color: AdminColors.textMuted),
                  ],
                ),
                if (e.metadata != null && e.metadata!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _metadata(e.metadata!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metadata(Map<String, dynamic> meta) {
    final entries = meta.entries.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${e.key}: ${e.value}',
              style: const TextStyle(
                fontSize: 11.5,
                color: AdminColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }

  Widget _pager() {
    final page = _page;
    if (page == null || page.events.isEmpty) return const SizedBox.shrink();
    final from = page.offset + 1;
    final to = page.offset + page.events.length;
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
                    setState(() =>
                        _offset = (page.offset - _pageSize).clamp(0, 1 << 31));
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: page.hasMore && !_loading
                ? () {
                    setState(() => _offset = page.offset + _pageSize);
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
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
    if (type.contains('export')) return Icons.download_outlined;
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
    if (type.contains('export')) return AdminColors.purple;
    return AdminColors.warning;
  }
}
