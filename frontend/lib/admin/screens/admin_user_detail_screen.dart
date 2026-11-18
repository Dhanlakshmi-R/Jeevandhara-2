import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_labels.dart';
import '../admin_models.dart';
import '../admin_nav.dart';
import '../admin_strings.dart';
import '../admin_theme.dart';
import '../widgets/admin_components.dart';
import '../widgets/admin_states.dart';

/// Screen 4.3 — a single account: who they are, what they did, where they are
/// signed in, with the two controls an operator needs (suspend, revoke session).
///
/// Opening this screen is itself audited by the backend (`admin_viewed_user`),
/// so this page never needs to claim it logged anything.
class AdminUserDetailScreen extends StatefulWidget {
  final int userId;
  final String? fallbackName;

  const AdminUserDetailScreen({
    super.key,
    required this.userId,
    this.fallbackName,
  });

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  bool _loading = true;
  bool _authFailed = false;
  String? _error;
  bool _changed = false;

  AdminUserDetail? _detail;
  List<AdminActivityEvent> _activity = const [];
  List<AdminSession> _sessions = const [];

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
        AdminApi.instance.user(widget.userId),
        AdminApi.instance.activity(actorUserId: widget.userId, limit: 40),
        AdminApi.instance.sessions(userId: widget.userId, activeOnly: true),
      ]);
      if (!mounted) return;
      setState(() {
        _detail = results[0] as AdminUserDetail;
        _activity = (results[1] as AdminActivityPage).events;
        _sessions = results[2] as List<AdminSession>;
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

  Future<void> _toggleSuspend() async {
    final user = _detail?.user;
    if (user == null) return;
    try {
      if (user.isActive) {
        await AdminApi.instance.suspendUser(user.id);
        _toast('${user.name} suspended.');
      } else {
        await AdminApi.instance.unsuspendUser(user.id);
        _toast('${user.name} reactivated.');
      }
      _changed = true;
      _load();
    } on AdminAuthException {
      _toast('Administrator access required.');
    } on AdminApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not update this user.');
    }
  }

  Future<void> _revoke(AdminSession s) async {
    try {
      await AdminApi.instance.revokeSession(s.id);
      if (!mounted) return;
      _toast('Session revoked.');
      _changed = true;
      _load();
    } on AdminApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast('Could not revoke this session.');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AdminColors.panelElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AdminColors.bg,
        appBar: AppBar(
          backgroundColor: AdminColors.bgDeep,
          foregroundColor: AdminColors.textPrimary,
          elevation: 0,
          title: Text(
            _detail?.user.name ?? widget.fallbackName ?? 'User',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          actions: [
            if (_detail != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _suspendButton(_detail!.user),
              ),
          ],
        ),
        body: _body(),
      ),
    );
  }

  Widget _suspendButton(AdminUser user) {
    final active = user.isActive;
    return FilledButton.icon(
      onPressed: _toggleSuspend,
      icon: Icon(active ? Icons.block_outlined : Icons.restore, size: 17),
      label: Text(active ? 'Suspend' : 'Reactivate'),
      style: FilledButton.styleFrom(
        backgroundColor:
            active ? AdminColors.danger : AdminColors.success,
        foregroundColor: active ? Colors.white : AdminColors.textOnPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }

  Widget _body() {
    if (_authFailed) return adminNoAccessView();
    if (_loading && _detail == null) return const AdminLoading();
    if (_error != null) return adminErrorView(_load);
    final detail = _detail!;
    return RefreshIndicator(
      onRefresh: _load,
      color: AdminColors.primary,
      backgroundColor: AdminColors.panel,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _profilePanel(detail),
          const SizedBox(height: 16),
          _statTiles(detail),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 960;
            final activity = _activityPanel();
            final sessions = _sessionsPanel();
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: activity),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: sessions),
                ],
              );
            }
            return Column(
              children: [activity, const SizedBox(height: 16), sessions],
            );
          }),
        ],
      ),
    );
  }

  Widget _profilePanel(AdminUserDetail detail) {
    final u = detail.user;
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: adminRoleColor(u.role).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(u.name),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: adminRoleColor(u.role),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            u.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AdminColors.textPrimary,
                            ),
                          ),
                        ),
                        if (u.isSuperadmin) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified,
                              size: 16, color: AdminColors.gold),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      u.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AdminBadge(
                            text: adminRoleLabel(u.role),
                            color: adminRoleColor(u.role)),
                        AdminBadge(
                          text: adminStatusLabel(u.isActive),
                          color: adminStatusColor(u.isActive),
                          icon: u.isActive
                              ? Icons.check_circle_outline
                              : Icons.block_outlined,
                        ),
                        AdminBadge(
                            text: u.authProvider,
                            color: AdminColors.info,
                            icon: Icons.login),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),
          Wrap(
            spacing: 40,
            runSpacing: 14,
            children: [
              _field('User ID', '#${u.id}'),
              _field('Phone', u.phone?.isNotEmpty == true ? u.phone! : '—'),
              _field('Location',
                  u.location?.isNotEmpty == true ? u.location! : '—'),
              _field('Joined', formatDay(u.createdAt)),
              _field('Profile', u.profileComplete ? 'Complete' : 'Incomplete'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700,
              color: AdminColors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AdminColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTiles(AdminUserDetail detail) {
    final tiles = [
      AdminMetricCard(
        label: 'Active sessions',
        value: '${detail.activeSessionCount}',
        icon: Icons.devices_outlined,
        accent: AdminColors.teal,
      ),
      AdminMetricCard(
        label: 'Activity events',
        value: '${detail.eventCount}',
        icon: Icons.bolt_outlined,
        accent: AdminColors.warning,
      ),
      AdminMetricCard(
        label: 'Last seen',
        value: detail.lastSeenAt == null ? '—' : formatDay(detail.lastSeenAt),
        icon: Icons.schedule_outlined,
        accent: AdminColors.info,
        hint: detail.lastSeenAt == null
            ? null
            : _timeOnly(detail.lastSeenAt!),
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 760 ? 3 : 1;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: cols == 1 ? 3.6 : 1.9,
        children: tiles,
      );
    });
  }

  Widget _activityPanel() {
    return AdminPanel(
      title: AdminStrings.of(AK.recentActivity),
      dense: true,
      child: _activity.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  AdminStrings.of(AK.noActivity),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AdminColors.textMuted,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < _activity.length; i++) ...[
                  _activityRow(_activity[i]),
                  if (i != _activity.length - 1)
                    const Divider(height: 16, color: AdminColors.divider),
                ],
              ],
            ),
    );
  }

  Widget _activityRow(AdminActivityEvent e) {
    final summary = (e.summaryEn?.trim().isNotEmpty ?? false)
        ? e.summaryEn!
        : (e.action != null ? '${e.action} · ${e.entityType ?? ''}' : e.eventType);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AdminColors.info.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.bolt_outlined,
              size: 15, color: AdminColors.info),
        ),
        const SizedBox(width: 11),
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
                formatDateTime(e.createdAt),
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

  Widget _sessionsPanel() {
    return AdminPanel(
      title: 'Sessions',
      subtitle: 'Active sign-ins',
      dense: true,
      child: _sessions.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No active sessions.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AdminColors.textMuted,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < _sessions.length; i++) ...[
                  _sessionRow(_sessions[i]),
                  if (i != _sessions.length - 1)
                    const Divider(height: 16, color: AdminColors.divider),
                ],
              ],
            ),
    );
  }

  Widget _sessionRow(AdminSession s) {
    final device = (s.deviceLabel?.trim().isNotEmpty ?? false)
        ? s.deviceLabel!
        : (s.userAgent ?? 'Unknown device');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.devices_outlined,
            size: 18, color: AdminColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${s.ipAddress ?? '—'} · started ${formatDateTime(s.startedAt)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AdminColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (s.isCurrent)
          const AdminBadge(text: 'Current', color: AdminColors.primary)
        else
          TextButton(
            onPressed: () => _revoke(s),
            style: TextButton.styleFrom(
              foregroundColor: AdminColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Revoke', style: TextStyle(fontSize: 12.5)),
          ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

  String _timeOnly(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
