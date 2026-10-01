import 'package:flutter/material.dart';

import 'package:jeevandhara2/app/destinations.dart';
import 'package:jeevandhara2/design/palette.dart';
import 'package:jeevandhara2/design/tokens.dart';
import 'package:jeevandhara2/design/typography.dart';
import 'package:jeevandhara2/models/user.dart';
import 'package:jeevandhara2/theme/locale.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';

/// Grouped navigation rail.
///
/// Grouped rather than flat because the destination list has grown past the
/// point where an unlabelled column is scannable: an assistant, a set of
/// tools, a marketplace and the account area are four different intentions and
/// the headings say which is which.
class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.role,
    required this.current,
    required this.onSelect,
    required this.onOpenPalette,
    this.user,
    this.unread = 0,
    this.collapsible = true,
  });

  final AppRole role;
  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;
  final VoidCallback onOpenPalette;
  final AppUser? user;
  final int unread;
  final bool collapsible;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  /// Collapsed shows icons only, and only for the assistant and tools groups;
  /// account items stay hidden to keep the column short.
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final groups = AppDestinations.groupsFor(widget.role);

    return AnimatedContainer(
      duration: Motion.normal,
      curve: Motion.emphasized,
      width: _collapsed ? Layout.sidebarCollapsed : Layout.sidebarExpanded,
      decoration: BoxDecoration(
        color: c.sidebarSurface,
        border: Border(right: BorderSide(color: context.ai.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Brand(collapsed: _collapsed),
          const SizedBox(height: Gap.sm),
          _PaletteHint(
            collapsed: _collapsed,
            onTap: widget.onOpenPalette,
          ),
          const SizedBox(height: Gap.lg),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                  horizontal: _collapsed ? Gap.sm : Gap.sm),
              children: [
                for (final group in groups) ...[
                  if (!_collapsed) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.md,
                        Gap.md,
                        Gap.md,
                        Gap.xs,
                      ),
                      child: Text(
                        context.str(group.labelKey).toUpperCase(),
                        style: AppType.label(context),
                      ),
                    ),
                  ] else if (group != groups.first)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: Gap.sm),
                      child: Divider(height: 1),
                    ),
                  for (final destination
                      in AppDestinations.inGroup(widget.role, group))
                    _NavItem(
                      destination: destination,
                      selected: destination == widget.current,
                      collapsed: _collapsed,
                      unread: destination == AppDestination.notifications
                          ? widget.unread
                          : 0,
                      onTap: () => widget.onSelect(destination),
                    ),
                ],
              ],
            ),
          ),
          if (widget.user != null)
            _AccountCard(
              user: widget.user!,
              collapsed: _collapsed,
              onTap: () => widget.onSelect(AppDestination.profile),
            ),
          if (widget.collapsible)
            _CollapseButton(
              collapsed: _collapsed,
              onTap: () => setState(() => _collapsed = !_collapsed),
            ),
          const SizedBox(height: Gap.sm),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.gutter, Gap.md, 0),
      child: Row(
        children: [
          const BrandMark(size: 38),
          if (!collapsed) ...[
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jeevandhara',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.navItem(context, selected: true)
                        .copyWith(fontSize: 15.5),
                  ),
                  Text(
                    'Krishi Assistant',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.meta(context),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Brand glyph. Kept local so the sidebar owns its own header rather than
/// reaching into the old shell.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: Radii.rMd,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.eco_rounded,
        size: size * 0.52,
        color: Colors.white,
      ),
    );
  }
}

class _PaletteHint extends StatelessWidget {
  const _PaletteHint({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
      child: Tooltip(
        message: 'Search and commands',
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: Radii.rMd,
            child: Container(
              height: 38,
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : Gap.md),
              alignment: collapsed ? Alignment.center : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: c.inputFill,
                borderRadius: Radii.rMd,
                border: Border.all(color: context.ai.hairline),
              ),
              child: collapsed
                  ? Icon(Icons.search_rounded, size: 18, color: c.textSecondary)
                  : Row(
                      children: [
                        Icon(Icons.search_rounded,
                            size: 16, color: c.textSecondary),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Text(
                            'Search',
                            style: AppType.meta(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const _KeyCap('Ctrl K'),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.rXs,
        border: Border.all(color: context.ai.hairline),
      ),
      child: Text(
        label,
        style: AppType.meta(context)
            .copyWith(fontSize: 10.5, color: c.textSecondary),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.onTap,
    this.unread = 0,
  });

  final AppDestination destination;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = context.str(destination.labelKey);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tooltip(
        message: collapsed ? label : '',
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: Radii.rMd,
            // Only tint on hover when there is a pointer to hover with; on
            // touch it just smears.
            hoverColor: c.primary.withValues(alpha: 0.06),
            child: AnimatedContainer(
              duration: Motion.fast,
              curve: Motion.emphasized,
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : Gap.md,
                vertical: Gap.sm + 2,
              ),
              decoration: BoxDecoration(
                color: selected ? c.primaryLight : Colors.transparent,
                borderRadius: Radii.rMd,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Icon(
                            selected
                                ? destination.selectedIcon
                                : destination.icon,
                            size: 19,
                            color: selected ? c.primary : c.textSecondary,
                          ),
                        ),
                        if (unread > 0)
                          Positioned(
                            right: 0,
                            top: 2,
                            child: _UnreadDot(count: unread),
                          ),
                      ],
                    ),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.navItem(context, selected: selected),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.danger,
        borderRadius: Radii.pill,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.user,
    required this.collapsed,
    required this.onTap,
  });

  final AppUser user;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.sm, 0, Gap.sm, Gap.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.rMd,
          child: Container(
            padding: EdgeInsets.all(collapsed ? Gap.xs : Gap.md),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: Radii.rMd,
              border: Border.all(color: context.ai.hairline),
            ),
            child: collapsed
                ? AppAvatar(name: user.name, size: 34)
                : Row(
                    children: [
                      AppAvatar(name: user.name, size: 34),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user.name.trim().isEmpty
                                  ? 'Account'
                                  : user.name.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.navItem(context, selected: true)
                                  .copyWith(fontSize: 13),
                            ),
                            Text(
                              user.role,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.meta(context)
                                  .copyWith(fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CollapseButton extends StatelessWidget {
  const _CollapseButton({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
      icon: AnimatedRotation(
        turns: collapsed ? 0.25 : 0,
        duration: Motion.normal,
        child: Icon(
          collapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
          size: 18,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}
