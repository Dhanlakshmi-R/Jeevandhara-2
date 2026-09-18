import 'package:flutter/material.dart';

/// Brand palette (light-theme static values) for Jeevandhara.
/// Theme-sensitive surfaces/text should use `context.colors` (ThemeColors).
class AppColors {
  // Primary brand
  static const primary = Color(0xFF1F6B45); // Deep Green
  static const primaryDark = Color(0xFF144D31);
  static const primaryLight = Color(0xFFE5F2E9);

  // Secondary brand
  static const secondary = Color(0xFF5DAE54); // Fresh Green
  static const secondaryLight = Color(0xFFEAF6E6);

  // Accent
  static const accent = Color(0xFFF4B942); // Golden Yellow

  // Neutrals (light theme)
  static const background = Color(0xFFF7FAF8);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE3EAE5);
  static const textPrimary = Color(0xFF1D2A22);
  static const textSecondary = Color(0xFF5C6B61);

  // Legacy aliases (kept for compatibility)
  static const textDark = textPrimary;
  static const textGrey = textSecondary;
  static const positiveLight = Color(0xFFE4F4EA);
  static const cream = Color(0xFFF4F6FA);
  static const earth = Color(0xFFB08968);

  // Semantics
  static const positive = Color(0xFF1F8A5E);
  static const negative = Color(0xFFD64545);
  static const warning = Color(0xFFF4B942);
  static const danger = Color(0xFFD64545);
  static const info = Color(0xFF2E86AB);
}

/// Theme-aware color palette. Access via `context.colors`.
class ThemeColors {
  final Brightness brightness;
  const ThemeColors(this.brightness);

  bool get isDark => brightness == Brightness.dark;

  static const _light = ThemeColors(Brightness.light);
  static const _dark = ThemeColors(Brightness.dark);

  static ThemeColors get light => _light;
  static ThemeColors get dark => _dark;

  Color get primary =>
      isDark ? const Color(0xFF4FA77A) : AppColors.primary;
  Color get primaryDark =>
      isDark ? const Color(0xFF2F8B5D) : AppColors.primaryDark;
  Color get primaryLight =>
      isDark ? const Color(0xFF1E3A2B) : AppColors.primaryLight;

  Color get secondary =>
      isDark ? const Color(0xFF70C066) : AppColors.secondary;
  Color get secondaryLight =>
      isDark ? const Color(0xFF213B27) : AppColors.secondaryLight;

  Color get accent => AppColors.accent;
  Color get accentLight =>
      isDark ? const Color(0xFF3A2F14) : const Color(0xFFFFF6DE);

  Color get onPrimary => Colors.white;

  Color get background =>
      isDark ? const Color(0xFF111B16) : AppColors.background;
  Color get surface =>
      isDark ? const Color(0xFF17241C) : AppColors.card;
  Color get surfaceAlt =>
      isDark ? const Color(0xFF1E2D23) : const Color(0xFFF0F5F1);
  Color get surfaceElevated =>
      isDark ? const Color(0xFF223127) : Colors.white;

  /// Slightly recessed surface (desktop sidebar, chips).
  Color get sidebarSurface =>
      isDark ? const Color(0xFF0E1813) : const Color(0xFFFBFDFB);

  Color get border =>
      isDark ? const Color(0xFF2A3A30) : AppColors.border;
  Color get divider =>
      isDark ? const Color(0xFF223129) : const Color(0xFFEFF4F0);

  Color get inputFill =>
      isDark ? const Color(0xFF101B14) : const Color(0xFFF2F6F3);

  Color get textPrimary =>
      isDark ? const Color(0xFFEEF6F0) : AppColors.textPrimary;
  Color get textSecondary =>
      isDark ? const Color(0xFFAFC2B4) : AppColors.textSecondary;
  Color get textOnAccent =>
      isDark ? const Color(0xFF2A2200) : const Color(0xFF3D3200);
  Color get textOnPrimary => Colors.white;

  Color get positive =>
      isDark ? const Color(0xFF58C98B) : AppColors.positive;
  Color get negative =>
      isDark ? const Color(0xFFE06B5E) : AppColors.negative;
  Color get warning => isDark ? const Color(0xFFF2B544) : AppColors.warning;
  Color get danger =>
      isDark ? const Color(0xFFE06060) : AppColors.danger;
  Color get info => isDark ? const Color(0xFF4FA3C6) : AppColors.info;

  Color get shadow =>
      isDark ? Colors.black.withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.06);

  /// Tinted status surfaces for badges, alert cards and message rows.
  Color get successSurface =>
      isDark ? const Color(0xFF14301F) : const Color(0xFFE5F4EC);
  Color get warnSurface =>
      isDark ? const Color(0xFF37290D) : const Color(0xFFFFF4D6);
  Color get dangerSurface =>
      isDark ? const Color(0xFF3A1A17) : const Color(0xFFFBE7E4);
  Color get infoSurface =>
      isDark ? const Color(0xFF142E3A) : const Color(0xFFE5F1F6);

  /// Scrim for hero/avatar gradients regardless of theme.
  Color get brandGradientStart =>
      isDark ? const Color(0xFF1F6B45) : const Color(0xFF1F6B45);
  Color get brandGradientEnd =>
      isDark ? const Color(0xFF0F3D28) : const Color(0xFF09301F);
}

extension ContextThemeColors on BuildContext {
  ThemeColors get colors => ThemeColors(Theme.of(this).brightness);
}