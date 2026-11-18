import 'package:flutter/material.dart';

/// Palette for the administrator console.
///
/// Grounded in the design reference palette (deep forest green, near-black
/// teal, emerald, mint) plus the semantic accents the spec calls for: blue for
/// information, amber for warnings, red for critical states.
class AdminColors {
  const AdminColors._();

  // Surfaces (dark-first)
  static const bg = Color(0xFF001416);
  static const bgDeep = Color(0xFF000F11);
  static const panel = Color(0xFF01272C);
  static const panelAlt = Color(0xFF012129);
  static const panelElevated = Color(0xFF01363A);
  static const sidebar = Color(0xFF001B1F);

  // Lines
  static const border = Color(0xFF10403D);
  static const borderStrong = Color(0xFF1B5B54);
  static const divider = Color(0xFF0A2E2E);

  // Brand
  static const primary = Color(0xFF2FB673); // emerald
  static const primaryDark = Color(0xFF1E7A47);
  static const primarySurface = Color(0xFF0B2E20);
  static const mint = Color(0xFF7CA969);
  static const cream = Color(0xFFE0D4AA);
  static const teal = Color(0xFF03BDA8);

  // Text
  static const textPrimary = Color(0xFFEFF7F1);
  static const textSecondary = Color(0xFFA9C4BB);
  static const textMuted = Color(0xFF6E8E88);
  static const textOnPrimary = Color(0xFF04241A);

  // Semantic
  static const success = Color(0xFF2BB673);
  static const info = Color(0xFF5DBCF7);
  static const warning = Color(0xFFF5A524);
  static const danger = Color(0xFFF0552A);
  static const critical = Color(0xFFF03C10);
  static const purple = Color(0xFF9A6BF0);
  static const gold = Color(0xFFFDCC18);

  static const shadow = Color(0x66000000);

  /// Distinct series colours for charts (role distribution, growth, etc.).
  static const chart = <Color>[
    primary,
    info,
    warning,
    purple,
    teal,
    danger,
  ];
}

/// The console is always dark green, independent of the personal app's
/// light/dark setting, so the admin workspace reads as its own product.
ThemeData buildAdminTheme() {
  const scheme = ColorScheme.dark(
    primary: AdminColors.primary,
    onPrimary: AdminColors.textOnPrimary,
    secondary: AdminColors.teal,
    onSecondary: AdminColors.textOnPrimary,
    surface: AdminColors.panel,
    onSurface: AdminColors.textPrimary,
    error: AdminColors.danger,
    onError: Colors.white,
    outline: AdminColors.border,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AdminColors.bg,
    splashFactory: InkSparkle.splashFactory,
  );

  final text = base.textTheme.apply(
    bodyColor: AdminColors.textPrimary,
    displayColor: AdminColors.textPrimary,
  );

  return base.copyWith(
    canvasColor: AdminColors.bg,
    dividerColor: AdminColors.divider,
    cardColor: AdminColors.panel,
    textTheme: text.copyWith(
      displaySmall: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: AdminColors.textPrimary,
      ),
      headlineSmall: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AdminColors.textPrimary,
      ),
      titleMedium: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AdminColors.textPrimary,
      ),
      bodyMedium: const TextStyle(
        fontSize: 13.5,
        height: 1.45,
        color: AdminColors.textSecondary,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        color: AdminColors.textMuted,
      ),
      labelLarge: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
    iconTheme: const IconThemeData(color: AdminColors.textSecondary, size: 20),
    dividerTheme: const DividerThemeData(
      color: AdminColors.divider,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AdminColors.panelAlt,
      hintStyle: const TextStyle(color: AdminColors.textMuted, fontSize: 13.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminColors.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AdminColors.primary,
        foregroundColor: AdminColors.textOnPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AdminColors.primary),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminColors.textPrimary,
        side: const BorderSide(color: AdminColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AdminColors.panelAlt,
      side: const BorderSide(color: AdminColors.border),
      labelStyle: const TextStyle(color: AdminColors.textSecondary, fontSize: 12.5),
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: AdminColors.panelElevated,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      textStyle: TextStyle(color: AdminColors.textPrimary, fontSize: 12),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AdminColors.primary),
  );
}

/// Convenience so widgets read `context.admin` like the rest of the app reads
/// `context.colors`.
extension AdminScope on BuildContext {
  Color get adminBg => AdminColors.bg;
}
