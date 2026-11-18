import 'dart:async';

import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_labels.dart';
import '../admin_models.dart';
import '../admin_nav.dart';
import '../admin_strings.dart';
import '../admin_theme.dart';
import '../widgets/admin_components.dart';
import '../widgets/admin_states.dart';
import 'admin_user_detail_screen.dart';

/// Screen 4.2 — User Management.
///
/// One page of accounts at a time, from `/admin/users`. Filters and paging are
/// sent to the server; nothing is filtered or invented client-side.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const _pageSize = 25;

  final _searchController = TextEditingController();
  Timer? _debounce;

  String _query = '';
  String? _role;
  String? _status;
  int _offset = 0;

  bool _loading = true;
  bool _authFailed = false;
  String? _error;
  AdminUserPage? _page;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _query = value;
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
      final page = await AdminApi.instance.users(
        query: _query,
        role: _role,
        status: _status,
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

  Future<void> _toggleSuspend(AdminUser user) async {
    final wasActive = user.isActive;
    try {
      if (wasActive) {
        await AdminApi.instance.suspendUser(user.id);
      } else {
        await AdminApi.instance.unsuspendUser(user.id);
      }
      if (!mounted) return;
      _toast(wasActive
          ? '${user.name} suspended.'
          : '${user.name} reactivated.');
      _load();
    } on AdminAuthException {
      if (!mounted) return;
      _toast('Administrator access required.');
    } on AdminApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast('Could not update this user.');
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

  Future<void> _openUser(AdminUser user) async {
    final changed = await openAdminPage<bool>(
      context,
      AdminUserDetailScreen(userId: user.id, fallbackName: user.name),
    );
    if (changed == true) _load();
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
    final total = _page?.total ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: AdminStrings.of(AK.navUsers),
            subtitle: _loading
                ? AdminStrings.of(AK.loading)
                : '$total ${AdminStrings.of(AK.users).toLowerCase()}',
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
          SizedBox(
            height: 46,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: AdminStrings.of(AK.search),
                      prefixIcon: const Icon(Icons.search, size: 19),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _roleFilter(),
                const SizedBox(width: 10),
                _statusFilter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleFilter() {
    final options = <String?, String>{
      null: AdminStrings.of(AK.all, fallback: 'All'),
      'farmer': AdminStrings.of(AK.roleFarmer),
      'trader': AdminStrings.of(AK.roleTrader),
      'vendor': AdminStrings.of(AK.roleVendor),
      'admin': AdminStrings.of(AK.roleAdmin),
    };
    return _dropdown(
      value: _role,
      hint: AdminStrings.of(AK.roleFarmer),
      width: 150,
      items: [
        for (final e in options.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: (v) {
        setState(() {
          _role = v;
          _offset = 0;
        });
        _load();
      },
    );
  }

  Widget _statusFilter() {
    return _dropdown(
      value: _status,
      hint: AdminStrings.of(AK.all, fallback: 'All'),
      width: 150,
      items: [
        DropdownMenuItem(
            value: null,
            child: Text(AdminStrings.of(AK.all, fallback: 'All'))),
        DropdownMenuItem(
            value: 'active', child: Text(AdminStrings.of(AK.active))),
        DropdownMenuItem(
            value: 'suspended', child: Text(AdminStrings.of(AK.suspended))),
      ],
      onChanged: (v) {
        setState(() {
          _status = v;
          _offset = 0;
        });
        _load();
      },
    );
  }

  Widget _dropdown({
    required String? value,
    required String hint,
    required double width,
    required List<DropdownMenuItem<String?>> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminColors.panelAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13)),
          isExpanded: true,
          dropdownColor: AdminColors.panelElevated,
          style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary),
          icon: const Icon(Icons.expand_more, color: AdminColors.textMuted),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _body() {
    if (_authFailed) return adminNoAccessView();
    if (_loading && _page == null) return const AdminLoading();
    if (_error != null) return adminErrorView(_load);
    final users = _page?.users ?? const <AdminUser>[];
    if (users.isEmpty) {
      return adminEmptyView(
        icon: Icons.person_search_outlined,
        title: AdminStrings.of(AK.emptyTitle),
        body: _query.isNotEmpty || _role != null || _status != null
            ? 'No accounts match these filters.'
            : AdminStrings.of(AK.emptyBody),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 760;
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        children: [
          if (wide)
            AdminPanel(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: AdminTable(
                columns: const [
                  AdminTableColumn('User', flex: 4),
                  AdminTableColumn('Role', flex: 2),
                  AdminTableColumn('Status', flex: 2),
                  AdminTableColumn('Joined', flex: 2),
                  AdminTableColumn('', flex: 2),
                ],
                rows: [
                  for (final u in users) _row(u, wide: true),
                ],
              ),
            )
          else
            for (final u in users) ...[
              _card(u),
              const SizedBox(height: 12),
            ],
        ],
      );
    });
  }

  Widget _row(AdminUser u, {required bool wide}) {
    return InkWell(
      onTap: () => _openUser(u),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(flex: 4, child: _identity(u)),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AdminBadge(
                  text: adminRoleLabel(u.role),
                  color: adminRoleColor(u.role),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AdminBadge(
                  text: adminStatusLabel(u.isActive),
                  color: adminStatusColor(u.isActive),
                  icon: u.isActive
                      ? Icons.check_circle_outline
                      : Icons.block_outlined,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatDay(u.createdAt),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AdminColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: _actions(u),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(AdminUser u) {
    return AdminPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _identity(u)),
              _actions(u),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AdminBadge(text: adminRoleLabel(u.role), color: adminRoleColor(u.role)),
              AdminBadge(
                text: adminStatusLabel(u.isActive),
                color: adminStatusColor(u.isActive),
                icon: u.isActive
                    ? Icons.check_circle_outline
                    : Icons.block_outlined,
              ),
              AdminBadge(
                text: formatDay(u.createdAt),
                color: AdminColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _identity(AdminUser u) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: adminRoleColor(u.role).withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            _initials(u.name),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: adminRoleColor(u.role),
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      u.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                  ),
                  if (u.isSuperadmin) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 14, color: AdminColors.gold),
                  ],
                ],
              ),
              Text(
                u.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AdminColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actions(AdminUser u) {
    return PopupMenuButton<String>(
      tooltip: '',
      color: AdminColors.panelElevated,
      icon: const Icon(Icons.more_horiz, color: AdminColors.textSecondary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AdminColors.border),
      ),
      onSelected: (value) {
        if (value == 'view') {
          _openUser(u);
        } else if (value == 'suspend') {
          _toggleSuspend(u);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.visibility_outlined,
                  size: 17, color: AdminColors.textSecondary),
              SizedBox(width: 10),
              Text('View details',
                  style: TextStyle(fontSize: 13, color: AdminColors.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'suspend',
          child: Row(
            children: [
              Icon(
                u.isActive ? Icons.block_outlined : Icons.restore,
                size: 17,
                color: u.isActive ? AdminColors.danger : AdminColors.success,
              ),
              const SizedBox(width: 10),
              Text(
                u.isActive ? 'Suspend' : 'Reactivate',
                style: TextStyle(
                  fontSize: 13,
                  color: u.isActive ? AdminColors.danger : AdminColors.success,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pager() {
    final page = _page;
    if (page == null || page.users.isEmpty) return const SizedBox.shrink();
    final from = page.offset + 1;
    final to = page.offset + page.users.length;
    final canPrev = page.offset > 0;
    final canNext = page.hasMore;
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
            onPressed: canPrev && !_loading
                ? () {
                    setState(() => _offset = (page.offset - _pageSize).clamp(0, 1 << 31));
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: canNext && !_loading
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }
}
