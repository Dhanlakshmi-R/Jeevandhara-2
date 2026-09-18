import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/locale.dart';
import 'layout.dart';
import 'ui/buttons.dart';
import 'ui/cards.dart';

/// Nav item descriptor for a dashboard shell.
class ShellItem {
  final String labelKey;
  final IconData icon;
  final IconData selectedIcon;
  final String? tooltip;

  const ShellItem({
    required this.labelKey,
    required this.icon,
    required this.selectedIcon,
    this.tooltip,
  });
}

/// Premium enterprise shell: collapsible sidebar (desktop/tablet),
/// bottom navigation (mobile), top bar with location, theme toggle,
/// notifications and profile avatar.
class DashboardShell extends StatefulWidget {
  final AppUser? user;
  final List<ShellItem> items;
  final List<Widget> pages;
  final int initialIndex;
  final bool showLocation;
  final List<int> mobileDestinations;
  final String defaultLocation;

  const DashboardShell({
    super.key,
    required this.user,
    required this.items,
    required this.pages,
    this.initialIndex = 0,
    this.showLocation = false,
    required this.mobileDestinations,
    this.defaultLocation = 'Dharwad, Karnataka',
  });

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  late int _index = widget.initialIndex;
  bool _collapsed = false;
  String _location = '';

  @override
  void initState() {
    super.initState();
    _location = widget.defaultLocation;
  }

  int _indexOfKey(String key) {
    for (var i = 0; i < widget.items.length; i++) {
      if (widget.items[i].labelKey == key) return i;
    }
    return 0;
  }

  int get _unread =>
      AppNotification.sampleData().where((n) => !n.seen).length;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    final desktop = Res.isDesktop(width) || Res.isTablet(width);

    final content = Builder(
      builder: (context) => Column(
        children: [
          _TopBar(
            title: context.str(widget.items[_index].labelKey),
            showLocation: widget.showLocation && width >= 420,
            location: _location,
            unread: _unread,
            onSelectLocation: (r) => setState(() => _location = r),
            onOpenNotifications: () => _select(_indexOfKey(K.notifications)),
            onOpenProfile: () => _select(_indexOfKey(K.profile)),
            onMenu: desktop ? null : () => Scaffold.of(context).openDrawer(),
          ),
          Expanded(
            child: IndexedStack(index: _index, children: widget.pages),
          ),
        ],
      ),
    );

    if (desktop) {
      return Scaffold(
        backgroundColor: c.background,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Sidebar(
              items: widget.items,
              selectedIndex: _index,
              collapsed: _collapsed,
              user: widget.user,
              onSelect: _select,
              onToggleCollapse: () => setState(() => _collapsed = !_collapsed),
            ),
            AnimatedContainer(
              duration: ThemeController.animDuration,
              width: _collapsed ? 0 : 1,
              decoration: BoxDecoration(
                color: c.divider,
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      drawer: Drawer(
        backgroundColor: c.surfaceElevated,
        child: SafeArea(
          child: _Sidebar(
            items: widget.items,
            selectedIndex: _index,
            collapsed: false,
            user: widget.user,
            onSelect: (i) {
              Navigator.pop(context);
              _select(i);
            },
          ),
        ),
      ),
      body: content,
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _index,
        onTap: (i) => _select(i),
        items: widget.mobileDestinations.map((idx) {
          final item = widget.items[idx];
          return NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: context.str(item.labelKey),
          );
        }).toList(),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<NavigationDestination> items;

  const _BottomNavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onTap,
        destinations: items,
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<ShellItem> items;
  final int selectedIndex;
  final bool collapsed;
  final AppUser? user;
  final ValueChanged<int> onSelect;
  final VoidCallback? onToggleCollapse;

  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.collapsed,
    this.user,
    required this.onSelect,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final width = collapsed ? 78.0 : 268.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
        color: c.sidebarSurface,
        border: Border(right: BorderSide(color: c.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Brand
          Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 18),
            child: Row(
              children: [
                _BrandMark(size: 40),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jeevandhara',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Krishi Platform',
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Nav items
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 8),
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _NavItem(
                      item: items[i],
                      selected: selectedIndex == i,
                      collapsed: collapsed,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
          ),
          // Footer
          if (user != null)
            Container(
              padding: EdgeInsets.all(collapsed ? 10 : 14),
              margin: EdgeInsets.fromLTRB(collapsed ? 8 : 12, 4, collapsed ? 8 : 12, collapsed ? 8 : 12),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: collapsed
                  ? const Center(child: AppAvatar(size: 36))
                  : Row(
                      children: [
                        AppAvatar(name: user!.name, size: 38),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user!.name.split(' ').first,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                user!.role.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          if (onToggleCollapse != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IconButton(
                tooltip: collapsed ? 'Expand menu' : 'Collapse menu',
                onPressed: onToggleCollapse,
                icon: AnimatedRotation(
                  turns: collapsed ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(collapsed ? Icons.menu_open : Icons.menu, color: c.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final double size;
  const _BrandMark({required this.size});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.primary, c.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
    );
  }
}

class _NavItem extends StatelessWidget {
  final ShellItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.primaryLight : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: collapsed ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        hoverColor: c.primary.withValues(alpha: 0.06),
        focusColor: c.primary.withValues(alpha: 0.10),
        splashColor: c.primary.withValues(alpha: 0.10),
        child: Tooltip(
          message: collapsed ? context.str(item.labelKey) : '',
          waitDuration: const Duration(milliseconds: 700),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 12,
              vertical: 11,
            ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? c.primary : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 19,
                  color: selected ? Colors.white : c.textSecondary,
                ),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.str(item.labelKey),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? c.primaryDark : c.textPrimary,
                    ),
                  ),
                ),
if (selected)
                  Icon(Icons.chevron_right, size: 15, color: c.primary),
              ],
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final bool showLocation;
  final String location;
  final int unread;
  final ValueChanged<String> onSelectLocation;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final VoidCallback? onMenu;

  const _TopBar({
    required this.title,
    required this.showLocation,
    required this.location,
    required this.unread,
    required this.onSelectLocation,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = _todayLabel();

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          if (onMenu != null) ...[
            AppIconButton(
              icon: Icons.menu_rounded,
              onPressed: onMenu,
              tooltip: 'Open navigation menu',
            ),
            const SizedBox(width: 4),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: c.textPrimary,
                ),
              ),
              Text(
                today,
                style: TextStyle(fontSize: 11.5, color: c.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          if (showLocation)
          _LocationPill(
            label: location,
            regions: const ['Dharwad', 'Hubballi', 'Belagavi', 'Gadag'],
            onSelected: onSelectLocation,
          ),
          const SizedBox(width: 12),
          const ThemeToggle(),
          const SizedBox(width: 8),
          _BellButton(unread: unread, onTap: onOpenNotifications),
          const SizedBox(width: 8),
          InkWell(
            onTap: onOpenProfile,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: c.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const AppAvatar(size: 38),
            ),
          ),
        ],
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

class _LocationPill extends StatelessWidget {
  final String label;
  final List<String> regions;
  final ValueChanged<String> onSelected;

  const _LocationPill({
    required this.label,
    required this.regions,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopupMenuButton<String>(
      tooltip: 'Select location',
      initialValue: regions.firstWhere(
        (r) => label.startsWith(r),
        orElse: () => regions.first,
      ),
      onSelected: onSelected,
      color: c.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => [
        for (final r in regions)
          PopupMenuItem(value: r, child: Text('$r, Karnataka')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_outlined, size: 16, color: c.primary),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                label.split(',')[0],
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 16, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;

  const _BellButton({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppIconButton(icon: Icons.notifications_none, onPressed: onTap, tooltip: 'Notifications'),
        if (unread > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: c.danger,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.surface, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}