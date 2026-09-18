import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

/// Premium sun/moon theme toggle with smooth 250ms transitions.
class ThemeToggle extends StatelessWidget {
  final Color? activeColor;
  final double size;

  const ThemeToggle({super.key, this.activeColor, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final controller = ThemeController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final mode = controller.mode;
        final isDark = mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);

        return Tooltip(
          message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          child: Material(
            color: activeColor != null
                ? Colors.white.withValues(alpha: 0.16)
                : c.surfaceAlt,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => controller.setMode(isDark ? ThemeMode.light : ThemeMode.dark),
              child: AnimatedContainer(
                duration: ThemeController.animDuration,
                curve: Curves.easeInOut,
                padding: EdgeInsets.all(size * 0.22),
                child: AnimatedSwitcher(
                  duration: ThemeController.animDuration,
                  transitionBuilder: (child, animation) {
                    return RotationTransition(
                      turns: animation,
                      child: child,
                    );
                  },
                  child: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    key: ValueKey(isDark ? 'dark' : 'light'),
                    size: size * 0.55,
                    color: activeColor ?? c.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Breakpoint helpers for responsive layouts.
abstract final class Res {
  static bool isDesktop(double width) => width >= 1024;
  static bool isTablet(double width) => width >= 720 && width < 1024;
  static bool isMobile(double width) => width < 720;

  static int gridCols(double width) {
    if (width >= 1280) return 4;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }
}

/// Responsive column count for card grids.
int responsiveCols(double width) {
  if (width >= 1000) return 4;
  if (width >= 700) return 3;
  if (width >= 450) return 2;
  return 1;
}