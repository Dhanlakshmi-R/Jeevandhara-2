import 'package:flutter/widgets.dart';

/// Spacing, radii, elevation and layout constants.
///
/// Everything is a multiple of 4 so surfaces stay on a consistent rhythm.
/// Use [Gap] rather than raw numbers so a density change lands everywhere.
class Gap {
  Gap._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 56;

  /// Vertical rhythm between major blocks in a scrolling page.
  static const double section = 24;

  /// Gutter for screen-level horizontal padding.
  static const double gutter = 20;

  /// Horizontal padding inside a card.
  static const double card = 18;
}

/// Corner radii. 12–20px reads as "soft but not toy-like".
class Radii {
  Radii._();

  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  static const BorderRadius rXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius rXxl = BorderRadius.all(Radius.circular(xxl));

  /// Pill shape for chips, badges and the composer.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Multi-layer soft shadows. Flat elevation reads cheaper than layered shadow,
/// so cards get an ambient pass plus a tighter contact pass.
class Elev {
  Elev._();

  static List<BoxShadow> xs(Color tint) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> sm(Color tint) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];

  static List<BoxShadow> md(Color tint) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: tint.withValues(alpha: 0.03),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> lg(Color tint) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.08),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: tint.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  /// Reserved for overlays (command palette, dialogs). Glass is for overlays
  /// only — never for content surfaces.
  static List<BoxShadow> overlay(Color tint) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.22),
          blurRadius: 48,
          offset: const Offset(0, 24),
        ),
        BoxShadow(
          color: tint.withValues(alpha: 0.10),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];
}

/// Backdrop blur for glassmorphic overlays.
class Blur {
  Blur._();

  static const double sm = 12;
  static const double md = 24;
  static const double lg = 40;
}

/// Fixed layout widths so sidebar/top bar stay consistent app-wide.
class Layout {
  Layout._();

  static const double sidebarExpanded = 272;
  static const double sidebarCollapsed = 76;
  static const double topBarHeight = 64;

  /// Reading width for long-form assistant answers.
  static const double readingMax = 760;

  /// Below this the shell switches to the mobile drawer.
  static const double desktopBreakpoint = 1000;
  static const double tabletBreakpoint = 720;
}
