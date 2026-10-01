import 'package:flutter/material.dart';

import 'package:jeevandhara2/app/destinations.dart';
import 'package:jeevandhara2/app/shell/sidebar.dart';
import 'package:jeevandhara2/app/shell/top_bar.dart';
import 'package:jeevandhara2/design/motion.dart';
import 'package:jeevandhara2/design/palette.dart';
import 'package:jeevandhara2/design/tokens.dart';
import 'package:jeevandhara2/models/user.dart';
import 'package:jeevandhara2/theme/locale.dart';

/// The phone layout: drawer for the full destination list, a compact top bar
/// and a bottom bar for the handful of destinations people switch to without
/// thinking.
///
/// The chat is the first bottom-bar slot because it is the app's front door,
/// and the other three are what someone reaches for mid-question.
class MobileShell extends StatelessWidget {
  const MobileShell({
    super.key,
    required this.role,
    required this.destinations,
    required this.current,
    required this.onSelect,
    required this.onOpenPalette,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    required this.built,
    required this.pageFor,
    this.user,
    this.unread = 0,
    this.locationLabel = '',
  });

  final AppRole role;
  final List<AppDestination> destinations;
  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;
  final VoidCallback onOpenPalette;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;

  /// Destinations opened so far, in visit order. Only these are in the
  /// stack, so an unvisited screen costs nothing.
  final List<AppDestination> built;
  final Widget Function(AppDestination) pageFor;
  final AppUser? user;
  final int unread;
  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = AppDestinations.mobile.where(destinations.contains).toList();

    return Scaffold(
      backgroundColor: c.background,
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        child: SafeArea(
          child: Sidebar(
            role: role,
            current: current,
            onSelect: (d) {
              Navigator.of(context).pop();
              onSelect(d);
            },
            user: user,
            unread: unread,
            onOpenPalette: () {
              Navigator.of(context).pop();
              onOpenPalette();
            },
            // No collapse control on a phone: there is no width to reclaim.
            collapsible: false,
          ),
        ),
      ),
      body: Column(
        children: [
          // `Builder` so the menu button's context sits below the Scaffold and
          // `Scaffold.of` can actually find the drawer to open.
          Builder(
            builder: (inner) => TopBar(
              title: context.str(current.labelKey),
              subtitle:
                  locationLabel.isEmpty ? context.str(K.chat) : locationLabel,
              locationLabel: locationLabel,
              unread: unread,
              onMenu: () => Scaffold.of(inner).openDrawer(),
              onOpenPalette: onOpenPalette,
              onOpenNotifications: onOpenNotifications,
              onOpenProfile: onOpenProfile,
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: built.indexOf(current),
              children: [
                for (final d in built)
                  KeyedSubtree(
                    key: ValueKey(d),
                    child: pageFor(d),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        destinations: bottom,
        current: current,
        unread: unread,
        onSelect: onSelect,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.destinations,
    required this.current,
    required this.onSelect,
    this.unread = 0,
  });

  final List<AppDestination> destinations;
  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (destinations.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: context.ai.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (final destination in destinations)
                Expanded(
                  child: _BottomItem(
                    destination: destination,
                    selected: destination == current,
                    unread: destination == AppDestination.notifications
                        ? unread
                        : 0,
                    onTap: () => onSelect(destination),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.unread = 0,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.primary : c.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      label: context.str(destination.labelKey),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: Motion.fast,
                  curve: Motion.emphasized,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? c.primaryLight : Colors.transparent,
                    borderRadius: Radii.pill,
                  ),
                  child: Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 21,
                    color: color,
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    right: Gap.sm,
                    top: 0,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 14, minHeight: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.danger,
                        borderRadius: Radii.pill,
                        border: Border.all(color: c.surface, width: 1.5),
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              context.str(destination.labelKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
