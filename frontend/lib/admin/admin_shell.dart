import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../screens/splash_screen.dart';
import '../theme/locale.dart';
import 'admin_destinations.dart';
import 'admin_sections.dart';
import 'admin_strings.dart';
import 'admin_theme.dart';

/// The administrator workspace frame: a persistent sidebar on wide screens, a
/// drawer on narrow ones, and a header carrying the account menu.
///
/// It applies its own always-dark theme so the console reads as a separate
/// product from the farmer/trader app, regardless of the personal theme mode.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminSection _section = AdminSection.dashboard;
  AppUser? _admin;
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    try {
      final user = await ApiService().getCurrentUser();
      if (mounted) setState(() => _admin = user);
    } catch (_) {
      // Identity is cosmetic here; the API layer still enforces access.
    }
  }

  void _open(AdminSection section) {
    if (_section == section) return;
    setState(() => _section = section);
    if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _signOut() async {
    await ApiService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildAdminTheme(),
      child: AnimatedBuilder(
        animation: LanguageController.instance,
        builder: (context, _) {
          return LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final content = _content();
            if (wide) {
              return Scaffold(
                backgroundColor: AdminColors.bg,
                body: Row(
                  children: [
                    _Sidebar(
                      section: _section,
                      collapsed: _sidebarCollapsed,
                      admin: _admin,
                      onSelect: _open,
                      onToggle: () => setState(
                          () => _sidebarCollapsed = !_sidebarCollapsed),
                      onSignOut: _signOut,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _Header(
                            admin: _admin,
                            section: _section,
                            showMenu: false,
                            onOpenSection: _open,
                            onSignOut: _signOut,
                          ),
                          Expanded(child: content),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return Scaffold(
              backgroundColor: AdminColors.bg,
              drawer: Drawer(
                backgroundColor: AdminColors.sidebar,
                width: 268,
                child: _Sidebar(
                  section: _section,
                  collapsed: false,
                  admin: _admin,
                  onSelect: _open,
                  onToggle: null,
                  onSignOut: _signOut,
                ),
              ),
              body: Column(
                children: [
                  _Header(
                    admin: _admin,
                    section: _section,
                    showMenu: true,
                    onOpenSection: _open,
                    onSignOut: _signOut,
                  ),
                  Expanded(child: content),
                ],
              ),
            );
          });
        },
      ),
    );
  }

  Widget _content() {
    return IndexedStack(
      index: _section.index,
      children: [
        for (final s in AdminSection.values)
          buildAdminSection(s, onNavigate: _open),
      ],
    );
  }
}

// ------------------------------------------------------------------- sidebar

class _Sidebar extends StatelessWidget {
  final AdminSection section;
  final bool collapsed;
  final AppUser? admin;
  final void Function(AdminSection section) onSelect;
  final VoidCallback? onToggle;
  final VoidCallback onSignOut;

  const _Sidebar({
    required this.section,
    required this.collapsed,
    required this.admin,
    required this.onSelect,
    required this.onToggle,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final width = collapsed ? 76.0 : 250.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      color: AdminColors.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _brand(),
            const Divider(color: AdminColors.divider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                children: [
                  for (final s in AdminSection.values)
                    _navItem(s),
                ],
              ),
            ),
            const Divider(color: AdminColors.divider),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _brand() {
    return Padding(
      padding: EdgeInsets.fromLTRB(collapsed ? 16 : 18, 18, 12, 18),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AdminColors.primary, AdminColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.eco_rounded,
                color: Colors.white, size: 20),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jeevandhara',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Admin Console',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.mint,
                    ),
                  ),
                ],
              ),
            ),
            if (onToggle != null)
              IconButton(
                tooltip: 'Collapse',
                onPressed: onToggle,
                iconSize: 18,
                icon: const Icon(Icons.chevron_left, color: AdminColors.textMuted),
              ),
          ],
        ],
      ),
    );
  }

  Widget _navItem(AdminSection s) {
    final selected = s == section;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => onSelect(s),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 12 : 13, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? AdminColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: selected
                    ? AdminColors.primary.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? s.selectedIcon : s.icon,
                  size: 19,
                  color: selected ? AdminColors.primary : AdminColors.textSecondary,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            selected ? AdminColors.textPrimary : AdminColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onToggle != null && collapsed)
            IconButton(
              tooltip: 'Expand',
              onPressed: onToggle,
              icon: const Icon(Icons.chevron_right, color: AdminColors.textMuted),
            ),
          if (!collapsed) ...[
            TextButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout, size: 17, color: AdminColors.danger),
              label: const Text(
                'Sign out',
                style: TextStyle(color: AdminColors.danger, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ] else
            IconButton(
              tooltip: 'Sign out',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout, color: AdminColors.danger, size: 19),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- header

class _Header extends StatelessWidget {
  final AppUser? admin;
  final AdminSection section;
  final bool showMenu;
  final void Function(AdminSection section) onOpenSection;
  final VoidCallback onSignOut;

  const _Header({
    required this.admin,
    required this.section,
    required this.showMenu,
    required this.onOpenSection,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: AdminColors.bgDeep,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu, color: AdminColors.textSecondary),
            ),
          if (showMenu) const SizedBox(width: 4),
          Text(
            AdminStrings.of(AK.console),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AdminColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 16, color: AdminColors.textMuted),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              section.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AdminColors.textPrimary,
              ),
            ),
          ),
          const Spacer(),
          _LanguageToggle(),
          const SizedBox(width: 6),
          _AccountMenu(
            admin: admin,
            onOpenSection: onOpenSection,
            onSignOut: onSignOut,
          ),
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final kn = LanguageController.instance.isKannada;
    return Tooltip(
      message: 'EN / ಕನ್ನಡ',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => LanguageController.instance
            .setLang(kn ? AppLang.english : AppLang.kannada),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminColors.border),
          ),
          child: Text(
            kn ? 'ಕನ್ನಡ' : 'EN',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  final AppUser? admin;
  final void Function(AdminSection section) onOpenSection;
  final VoidCallback onSignOut;

  const _AccountMenu({
    required this.admin,
    required this.onOpenSection,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final name = admin?.name ?? AdminStrings.of(AK.administrator);
    final initials = _initials(name);
    return PopupMenuButton<String>(
      tooltip: name,
      color: AdminColors.panelElevated,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AdminColors.border),
      ),
      onSelected: (value) {
        if (value == 'security') {
          onOpenSection(AdminSection.profileSecurity);
        } else if (value == 'signout') {
          onSignOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary,
                ),
              ),
              if (admin?.email != null) ...[
                const SizedBox(height: 2),
                Text(
                  admin!.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'security',
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 17, color: AdminColors.textSecondary),
              SizedBox(width: 10),
              Text('Profile & Security',
                  style: TextStyle(color: AdminColors.textPrimary, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 17, color: AdminColors.danger),
              SizedBox(width: 10),
              Text('Sign out',
                  style: TextStyle(color: AdminColors.danger, fontSize: 13)),
            ],
          ),
        ),
      ],
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AdminColors.primary, AdminColors.primaryDark],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.expand_more, size: 18, color: AdminColors.textMuted),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.isEmpty ? 'A' : name.substring(0, 1).toUpperCase();
  }
}
