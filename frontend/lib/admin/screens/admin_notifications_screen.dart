import 'dart:async';

import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_models.dart';
import '../admin_strings.dart';
import '../admin_theme.dart';
import '../widgets/admin_components.dart';
import '../widgets/admin_states.dart';

/// Screen 4.9 - Notifications.
/// 
/// Send notifications to audiences (all/role/location/user). Shows history.
class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _title = TextEditingController();
  final _bodyEn = TextEditingController();
  final _bodyKn = TextEditingController();
  final _audVal = TextEditingController();

  String _priority = 'info';
  String _audience = 'all';
  final _limit = 50;

  bool _loading = true;
  bool _authFailed = false;
  String? _error;
  List<AdminNotification> _items = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _bodyEn.dispose();
    _bodyKn.dispose();
    _audVal.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _authFailed = false;
    });
    try {
      final list = await AdminApi.instance.notifications(limit: _limit);
      if (!mounted) return;
      setState(() {
        _items = list;
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

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _bodyEn.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'body_en': _bodyEn.text.trim(),
      'priority': _priority,
      'audience': _audience,
    };
    if (_bodyKn.text.trim().isNotEmpty) payload['body_kn'] = _bodyKn.text.trim();
    if (_audience != 'all') {
      payload['audience_value'] = _audVal.text.trim();
    }
    try {
      await AdminApi.instance.sendNotification(payload);
      if (mounted) {
        _title.clear();
        _bodyEn.clear();
        _bodyKn.clear();
        _audVal.clear();
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send notification')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _header(),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: AdminStrings.of(AK.navNotifications),
            subtitle: _loading
                ? AdminStrings.of(AK.loading)
                : '${_items.length} sent',
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
          _composer(),
        ],
      ),
    );
  }

  Widget _composer() {
    return AdminPanel(
      title: 'Send notification',
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _title,
                  decoration: const InputDecoration(hintText: 'Title'),
                ),
              ),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _bodyEn,
                  decoration: const InputDecoration(hintText: 'Body (EN)'),
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  value: _priority,
                  items: const ['info', 'warning', 'critical']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v ?? 'info'),
                  decoration: const InputDecoration(labelText: 'Priority'),
                ),
              ),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  value: _audience,
                  items: const ['all', 'role', 'location', 'user']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _audience = v ?? 'all'),
                  decoration: const InputDecoration(labelText: 'Audience'),
                ),
              ),
              if (_audience != 'all')
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _audVal,
                    decoration: InputDecoration(
                      hintText: _audience == 'role'
                          ? 'farmer/trader/vendor/admin'
                          : _audience == 'location'
                              ? 'location substring'
                              : 'user id',
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send, size: 16),
                label: Text(_sending ? 'Sending...' : 'Send'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyKn,
            decoration: const InputDecoration(hintText: 'Body (KN, optional)'),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_authFailed) return adminNoAccessView();
    if (_loading) return const AdminLoading();
    if (_error != null) return adminErrorView(_load);
    if (_items.isEmpty) {
      return adminEmptyView(
        icon: Icons.notifications_none,
        body: 'No notifications sent yet.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _noteCard(_items[i]),
    );
  }

  Widget _noteCard(AdminNotification n) {
    return AdminPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  n.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
              ),
              Text(
                n.createdAt == null ? '' : n.createdAt!.toString(),
                style: const TextStyle(fontSize: 11.5, color: AdminColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            n.bodyEn,
            style: const TextStyle(fontSize: 12.5, color: AdminColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              AdminBadge(text: n.priority, color: AdminColors.info),
              AdminBadge(text: 'aud: ${n.audience}', color: AdminColors.mint),
              if (n.audienceSummary != null)
                AdminBadge(text: n.audienceSummary!, color: AdminColors.textMuted),
              AdminBadge(
                text: '${n.recipientCount} recipients',
                color: AdminColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}