import 'package:flutter/material.dart';

import 'package:jeevandhara2/design/palette.dart';
import 'package:jeevandhara2/design/tokens.dart';
import 'package:jeevandhara2/design/typography.dart';
import 'package:jeevandhara2/widgets/layout.dart';
import 'package:jeevandhara2/widgets/ui/buttons.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';

/// The persistent header above the content area.
///
/// Carries the current destination's name, the date, the assistant's location
/// context and the three controls a user reaches for mid-task. Everything here
/// is a jump to somewhere else, so nothing on it owns a long-lived state.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onOpenPalette,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    this.locationLabel = '',
    this.unread = 0,
    this.onMenu,
  });

  final String title;
  final String subtitle;

  /// Empty means no location has been chosen, and the control is hidden rather
  /// than showing a placeholder the assistant cannot use.
  final String locationLabel;
  final int unread;
  final VoidCallback onOpenPalette;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final width = MediaQuery.sizeOf(context).width;

    return Container(
      height: Layout.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: Gap.md),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: context.ai.hairline)),
      ),
      child: Row(
        children: [
          if (onMenu != null) ...[
            AppIconButton(
              icon: Icons.menu_rounded,
              onPressed: onMenu,
              tooltip: 'Open navigation',
            ),
            const SizedBox(width: Gap.xs),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.navItem(context, selected: true)
                      .copyWith(fontSize: 17),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.meta(context),
                ),
              ],
            ),
          ),
          if (locationLabel.isNotEmpty && width >= 520) ...[
            _LocationChip(label: locationLabel),
            const SizedBox(width: Gap.sm),
          ],
          // On narrow screens the palette hint is redundant: the bottom bar
          // already exposes a search button.
          if (width >= 640) ...[
            _PaletteButton(onTap: onOpenPalette),
            const SizedBox(width: Gap.xs),
          ],
          const ThemeToggle(size: 36),
          const SizedBox(width: Gap.xs),
          _BellButton(unread: unread, onTap: onOpenNotifications),
          const SizedBox(width: Gap.xs),
          InkWell(
            onTap: onOpenProfile,
            borderRadius: Radii.pill,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: AppAvatar(size: 32),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Read-only by design: the location is chosen in the Weather flow, which
    // can resolve a village down to its coordinates. Offering a dropdown here
    // would let the user set a place the assistant has no coordinates for.
    return Tooltip(
      message: 'Location used for weather answers',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 7),
        decoration: BoxDecoration(
          color: c.inputFill,
          borderRadius: Radii.pill,
          border: Border.all(color: context.ai.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_rounded, size: 14, color: c.primary),
            const SizedBox(width: Gap.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.meta(context).copyWith(color: c.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteButton extends StatelessWidget {
  const _PaletteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: 'Search and commands',
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: c.inputFill,
        borderRadius: Radii.pill,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.pill,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            decoration: BoxDecoration(
              borderRadius: Radii.pill,
              border: Border.all(color: context.ai.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_rounded, size: 16, color: c.textSecondary),
                const SizedBox(width: Gap.xs),
                Text('Search', style: AppType.meta(context)),
                const SizedBox(width: Gap.sm),
                Icon(Icons.arrow_forward_rounded,
                    size: 13, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppIconButton(
          icon: Icons.notifications_none_rounded,
          onPressed: onTap,
          tooltip: 'Notifications',
        ),
        if (unread > 0)
          Positioned(
            right: 3,
            top: 3,
            child: AnimatedSlide(
              duration: Motion.normal,
              offset: Offset.zero,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
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
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
