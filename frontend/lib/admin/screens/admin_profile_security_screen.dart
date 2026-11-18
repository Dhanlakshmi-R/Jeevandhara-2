import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_models.dart';
import '../admin_strings.dart';
import '../admin_theme.dart';
import '../widgets/admin_components.dart';
import '../widgets/admin_states.dart';

/// Screen 4.10 - Profile & Security (and Permissions).
/// 
/// Shows the live permission matrix and a minimal read-only "security notes"
/// block. No credentials are ever shown.
class AdminProfileSecurityScreen extends StatefulWidget {
  const AdminProfileSecurityScreen({super.key});

  @override
  State<AdminProfileSecurityScreen> createState() =>
      _AdminProfileSecurityScreenState();
}

class _AdminProfileSecurityScreenState extends State<AdminProfileSecurityScreen> {
  bool _loading = true;
  bool _authFailed = false;
  String? _error;
  AdminPermissions? _perm;

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
      final p = await AdminApi.instance.permissions();
      if (!mounted) return;
      setState(() {
        _perm = p;
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
        _header(),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: AdminPageHeader(
        title: AdminStrings.of(AK.navSecurity),
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
    );
  }

  Widget _body() {
    if (_authFailed) return adminNoAccessView();
    if (_loading) return const AdminLoading();
    if (_error != null) return adminErrorView(_load);
    final p = _perm;
    if (p == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        AdminPanel(
          title: 'Security notes',
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '• Tokens are short-lived; revoking sessions immediately kills them.',
                style: TextStyle(color: AdminColors.textSecondary, fontSize: 12.5),
              ),
              SizedBox(height: 4),
              Text(
                '• Only administrators reach this console (server-side guard).',
                style: TextStyle(color: AdminColors.textSecondary, fontSize: 12.5),
              ),
              SizedBox(height: 4),
              Text(
                '• No passwords or secrets are ever shown or stored client-side.',
                style: TextStyle(color: AdminColors.textSecondary, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AdminPanel(
          title: 'Permission matrix (live)',
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              for (final c in p.capabilities)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.label,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AdminColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              c.description,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AdminColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final r in p.roles)
                            AdminBadge(
                              text: r,
                              color: c.roles.contains(r)
                                  ? AdminColors.success
                                  : AdminColors.textMuted,
                              solid: c.roles.contains(r),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}