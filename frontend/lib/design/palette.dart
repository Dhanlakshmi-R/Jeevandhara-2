import 'package:flutter/material.dart';

import 'package:jeevandhara2/theme/colors.dart';

export 'package:jeevandhara2/theme/colors.dart';

/// Extended semantic colors for the AI-app layer.
///
/// [ThemeColors] (via `context.colors`) stays the base vocabulary every
/// existing screen already uses. This adds the pieces an assistant UI needs
/// that the base palette has no slot for: aurora hues for the hero mesh,
/// glass fills for overlays, and hairline borders that stay quiet.
class AiPalette {
  final Brightness brightness;

  const AiPalette(this.brightness);

  bool get isDark => brightness == Brightness.dark;

  static const _light = AiPalette(Brightness.light);
  static const _dark = AiPalette(Brightness.dark);

  static AiPalette get light => _light;
  static AiPalette get dark => _dark;

  // ---------------------------------------------------------------- aurora

  /// Hues for the animated hero mesh behind the empty chat state. Deliberately
  /// desaturated: they sit at 6–12% opacity, so saturation here would read as
  /// banding rather than depth.
  List<Color> get aurora => isDark
      ? const [
          Color(0xFF1F6B45), // brand green
          Color(0xFF2E86AB), // info teal
          Color(0xFF5DAE54), // fresh green
          Color(0xFFF4B942), // brand gold
        ]
      : const [
          Color(0xFF1F6B45),
          Color(0xFF2E86AB),
          Color(0xFF5DAE54),
          Color(0xFFF4B942),
        ];

  /// Very soft wash used behind the greeting. Light mode needs less than dark
  /// or the copy stops being readable.
  List<Color> get auroraWash => isDark
      ? const [Color(0x141F6B45), Color(0x0D2E86AB), Color(0x0FF4B942)]
      : const [Color(0x0F1F6B45), Color(0x0A2E86AB), Color(0x0DF4B942)];

  // ----------------------------------------------------------------- glass

  /// Fill for overlays only: command palette, sheets, dialogs.
  Color get glass => isDark ? const Color(0xF21A241E) : const Color(0xF7FFFFFF);

  Color get glassStrong =>
      isDark ? const Color(0xFA1F2B23) : const Color(0xFCFFFFFF);

  /// 1px inner highlight that makes glass read as a lit surface.
  Color get glassHighlight =>
      Colors.white.withValues(alpha: isDark ? 0.06 : 0.7);

  // --------------------------------------------------------------- hairlines

  /// Border for elevated/hovered surfaces. Quieter than [ThemeColors.border].
  Color get hairline =>
      isDark ? const Color(0x332F4038) : const Color(0x14000000);

  // ------------------------------------------------------------------ code

  Color get codeSurface =>
      isDark ? const Color(0xFF121A16) : const Color(0xFFF4F7F5);

  Color get codeBorder =>
      isDark ? const Color(0xFF243028) : const Color(0xFFE2E9E4);

  // ----------------------------------------------------------------- chat

  /// Assistant messages sit on the page with no fill of their own, so the
  /// only thing separating them is the avatar dot and leading whitespace.
  Color get assistantSurface => Colors.transparent;

  /// User messages get a quiet tinted panel so the turn order is readable
  /// without the assistant side needing a bubble.
  Color get userBubble =>
      isDark ? const Color(0xFF1E2C24) : const Color(0xFFEDF4F0);

  Color get userBubbleBorder =>
      isDark ? const Color(0xFF2C3D33) : const Color(0xFFDCE8E1);

  /// System/notice rows: auth redirects, tool failures, offline warnings.
  Color get systemBubble =>
      isDark ? const Color(0xFF1B2420) : const Color(0xFFF6F8F7);

  // ------------------------------------------------------------- skeletons

  Color get skeletonBase =>
      isDark ? const Color(0xFF1E2922) : const Color(0xFFEAF0EC);

  Color get skeletonSheen =>
      isDark ? const Color(0xFF2A382F) : const Color(0xFFF5F9F6);

  // ------------------------------------------------------------- selection

  Color get selection =>
      (isDark ? const Color(0xFF4FA77A) : const Color(0xFF1F6B45))
          .withValues(alpha: 0.22);
}

extension AiPaletteX on BuildContext {
  AiPalette get ai => AiPalette(Theme.of(this).brightness);
}
