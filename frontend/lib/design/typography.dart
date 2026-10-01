import 'package:flutter/material.dart';

import 'package:jeevandhara2/theme/colors.dart';

export 'package:jeevandhara2/design/motion.dart';

/// Type scale for the assistant surface.
///
/// The existing [TextTheme] in `app_theme.dart` is left intact for the feature
/// screens. These styles are additive and are what the chat, sidebar and
/// command palette use, so the conversational surface can have its own rhythm
/// without restyling 21 screens.
class AppType {
  AppType._();

  /// Display voice for the empty-state greeting.
  static TextStyle greeting(BuildContext context) {
    final c = context.colors;
    return TextStyle(
      fontSize: 30,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: c.textPrimary,
    );
  }

  /// Two-line capability summary under the greeting.
  static TextStyle lede(BuildContext context) {
    final c = context.colors;
    return TextStyle(
      fontSize: 14.5,
      height: 1.6,
      fontWeight: FontWeight.w400,
      color: c.textSecondary,
    );
  }

  /// Assistant body copy. Slightly larger line height than the feature
  /// screens because answers are read, not scanned.
  static TextStyle answer(BuildContext context) {
    final c = context.colors;
    return TextStyle(
      fontSize: 15,
      height: 1.65,
      fontWeight: FontWeight.w400,
      color: c.textPrimary,
    );
  }

  static TextStyle userTurn(BuildContext context) {
    final c = context.colors;
    return TextStyle(
      fontSize: 15,
      height: 1.55,
      fontWeight: FontWeight.w500,
      color: c.textPrimary,
    );
  }

  /// Section headers and sidebar group labels. The negative tracking keeps
  /// short caps-style labels from looking gappy.
  static TextStyle label(BuildContext context) {
    final c = context.colors;
    return TextStyle(
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.7,
      color: c.textSecondary,
    );
  }

  /// Sidebar item text.
  static TextStyle navItem(BuildContext context, {required bool selected}) {
    final c = context.colors;
    return TextStyle(
      fontSize: 14,
      height: 1.3,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      color: selected ? c.textPrimary : c.textSecondary,
    );
  }

  /// Composer placeholder / input text.
  static TextStyle composer(BuildContext context) {
    final c = context.colors;
    return TextStyle(
      fontSize: 15,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: c.textPrimary,
    );
  }

  /// Monospace block for code and JSON payloads.
  static TextStyle code(BuildContext context) {
    final c = context.colors;
    return TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Consolas', 'Courier New'],
      fontSize: 13,
      height: 1.55,
      fontWeight: FontWeight.w400,
      color: c.textPrimary,
    );
  }

  /// Metadata under cards and chips: sources, timestamps, coordinates.
  static TextStyle meta(BuildContext context) {
    final c = context.colors;
    return TextStyle(
      fontSize: 11.5,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: c.textSecondary,
    );
  }

  /// Tabular figures for prices and temperatures so columns line up.
  static TextStyle numeric(BuildContext context, {double size = 22}) {
    final c = context.colors;
    return TextStyle(
      fontSize: size,
      height: 1.1,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: c.textPrimary,
    );
  }
}
