import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Original, theme-aware agriculture illustration.
///
/// Drawn entirely from Material shapes + icons (no external assets), so it
/// stays crisp at any size. `AgriSceneKind` picks a scene; `onDark` flips
/// the palette for hero panels that already carry a brand gradient.
enum AgriSceneKind {
  farm, // rolling hills, sun, crop rows, tree
  sunrise, // harvest-time glow, tractor silhouette
  market, // crates of produce + price tags
  weather, // sun, clouds, rain
  tools, // spade, cart and equipment
  quality, // magnifier over a leaf
  trade, // handshake + grain sacks (trader)
  onboarding, // compact field scene for onboarding
}

class AgriScene extends StatelessWidget {
  /// Design-time canvas ratio (w:h). Used to preserve a stable aspect ratio.
  static const double designAspect = 1.4;

  final AgriSceneKind kind;
  final bool onDark;
  final double? width;
  final double? height;

  const AgriScene({
    super.key,
    this.kind = AgriSceneKind.farm,
    this.onDark = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    const cw = 420.0;
    const ch = 300.0;

    final scene = _SceneRenderer(kind: kind, onDark: onDark).render(context);

    Widget content = FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(width: cw, height: ch, child: scene),
    );

    if (width != null || height != null) {
      content = SizedBox(width: width, height: height, child: content);
    }
    return content;
  }
}

/// Draws a scene inside the 420x300 design space.
class _SceneRenderer {
  final AgriSceneKind kind;
  final bool onDark;
  _SceneRenderer({required this.kind, required this.onDark});

  Color get _sun => const Color(0xFFF6BE55);
  Color get _deepGreen => const Color(0xFF1F6B45);
  Color get _midGreen => const Color(0xFF3E8B5A);
  Color get _lightGreen => const Color(0xFF6FAF62);
  Color get _gold => const Color(0xFFE0A430);

  Color _w(Color c, double a) => Colors.white.withValues(alpha: a);

  Widget render(BuildContext context) {
    final c = context.colors;
    final skyTop = onDark ? c.primary.withValues(alpha: 0.16) : const Color(0xFFFDF3D7);
    final skyBottom = onDark ? c.brandGradientEnd.withValues(alpha: 0.35) : const Color(0xFFE6F5E4);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [skyTop, skyBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: switch (kind) {
          AgriSceneKind.farm => _farm(c),
          AgriSceneKind.sunrise => _sunrise(c),
          AgriSceneKind.market => _market(c),
          AgriSceneKind.weather => _weather(c),
          AgriSceneKind.tools => _tools(c),
          AgriSceneKind.quality => _quality(c),
          AgriSceneKind.trade => _trade(c),
          AgriSceneKind.onboarding => _onboarding(c),
        },
      ),
    );
  }

  // ── Background helpers ────────────────────────────────────────────────────

  Widget _sunShape({double x = 316, double y = 36, double size = 52}) {
    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: onDark ? _w(_sun, 0.9) : _sun,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: onDark ? _w(_gold, 0.5) : _gold.withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: 6,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cloud({double left = 30, double top = 44, double w = 64, double a = 0.5}) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: w,
        height: 18,
        decoration: BoxDecoration(
          color: onDark ? _w(Colors.white, a) : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Rolling hill. `side` picks a base-hue; drawn as soft overlapping layers.
  Widget _hill({
    required double left,
    required double bottom,
    required double w,
    required double h,
    required Color color,
    double alpha = 1,
  }) {
    return Positioned(
      left: left,
      bottom: bottom,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: color.withValues(alpha: alpha),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(w),
            topRight: Radius.circular(w),
          ),
        ),
      ),
    );
  }

  Widget _cropRow({required double left, required double bottom, required int stalks}) {
    return Positioned(
      left: left,
      bottom: bottom,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(stalks, (i) {
          final green = onDark ? _w(_lightGreen, 0.7) : _midGreen;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(width: 4, height: 14 + (i % 3) * 5, color: green, alignment: Alignment.topCenter,
              child: Container(width: 6, height: 5, color: onDark ? _w(_lightGreen, 0.7) : _midGreen)),
          );
        }),
      ),
    );
  }

  Widget _tree({required double left, required double bottom}) {
    final trunk = onDark ? _w(Colors.white, 0.5) : const Color(0xFF8A5A33);
    final leaf = onDark ? _w(_deepGreen, 0.55) : _deepGreen;
    return Positioned(
      left: left,
      bottom: bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 38,
            decoration: BoxDecoration(
              color: leaf,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
          ),
          Container(width: 9, height: 20, color: trunk),
        ],
      ),
    );
  }

  // ── Scenes ────────────────────────────────────────────────────────────────

  List<Widget> _farm(ThemeColors c) {
    return [
      _sunShape(),
      _cloud(left: 40, top: 56, w: 60),
      _cloud(left: 150, top: 34, w: 74),
      _hill(left: -40, bottom: -20, w: 230, h: 140, color: onDark ? _deepGreen : _lightGreen, alpha: onDark ? 0.5 : 0.55),
      _hill(left: 150, bottom: -40, w: 300, h: 165, color: onDark ? _midGreen : _midGreen, alpha: onDark ? 0.55 : 0.85),
      _hill(left: 300, bottom: -30, w: 180, h: 130, color: onDark ? _lightGreen : _deepGreen, alpha: onDark ? 0.5 : 0.75),
      _cropRow(left: 70, bottom: 68, stalks: 11),
      _cropRow(left: 210, bottom: 46, stalks: 9),
      _cropRow(left: 330, bottom: 60, stalks: 10),
      _tree(left: 24, bottom: 74),
      _tree(left: 358, bottom: 60),
      _fence(left: 128, bottom: 108),
      if (onDark) Positioned(right: 24, bottom: 22, child: Icon(Icons.eco, size: 34, color: _w(_gold, 0.85)))
      else Positioned(right: 24, bottom: 22, child: Icon(Icons.eco, size: 34, color: _gold)),
    ];
  }

  Widget _fence({required double left, required double bottom}) {
    const post = 5.0;
    return Positioned(
      left: left,
      bottom: bottom,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 12; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: post,
                height: 20 + (i.isEven ? 4 : 0),
                color: onDark ? _w(Colors.white, 0.35) : Colors.brown.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _sunrise(ThemeColors c) {
    return [
      _sunShape(x: 180, y: 40, size: 66),
      _cloud(left: 60, top: 60, w: 70, a: 0.45),
      _cloud(left: 250, top: 84, w: 56, a: 0.35),
      _hill(left: -60, bottom: -30, w: 260, h: 150, color: onDark ? _lightGreen : _midGreen, alpha: onDark ? 0.5 : 0.6),
      _hill(left: 170, bottom: -50, w: 300, h: 175, color: onDark ? _deepGreen : _lightGreen, alpha: onDark ? 0.6 : 0.75),
      _cropRow(left: 96, bottom: 54, stalks: 10),
      _cropRow(left: 250, bottom: 40, stalks: 8),
      // tractor silhouette
      Positioned(
        left: 108,
        bottom: 62,
        child: Icon(
          Icons.precision_manufacturing_rounded,
          color: onDark ? _w(Colors.white, 0.4) : const Color(0xFF7A4A25),
          size: 46,
        ),
      ),
      Positioned(
        left: 60,
        bottom: 12,
        child: Icon(Icons.agriculture_rounded, color: onDark ? _w(_gold, 0.8) : _gold, size: 34),
      ),
    ];
  }

  List<Widget> _market(ThemeColors c) {
    final wood = onDark ? _w(Colors.white, 0.35) : const Color(0xFFB07C44);
    final woodLight = onDark ? _w(Colors.white, 0.22) : const Color(0xFFD9A666);
    Widget crate(double left, double bottom, double size, {String emoji = ''}) {
      return Positioned(
        left: left,
        bottom: bottom,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: wood,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: woodLight, width: 3),
          ),
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(emoji, style: TextStyle(fontSize: size * 0.34)),
          ),
        ),
      );
    }

    return [
      _cloud(left: 44, top: 48, w: 62),
      _sunShape(x: 308, y: 40, size: 46),
      _hill(left: -30, bottom: -40, w: 500, h: 170, color: onDark ? _midGreen : _lightGreen, alpha: onDark ? 0.5 : 0.7),
      crate(40, 78, 64, emoji: '\uD83C\uDF45'),
      crate(118, 56, 84, emoji: '\uD83E\uDDC5'),
      crate(216, 84, 60, emoji: '\uD83C\uDF3E'),
      crate(288, 50, 78, emoji: '\uD83E\uDD5C'),
      // price tag
      Positioned(
        right: 40,
        top: 128,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: onDark ? _w(_gold, 0.95) : _gold,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '\u20B9 30/kg',
            style: TextStyle(
              color: const Color(0xFF3D3200),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      Positioned(
        left: 24,
        bottom: 150,
        child: Icon(Icons.storefront_rounded, color: onDark ? _w(_gold, 0.8) : _gold, size: 38),
      ),
    ];
  }

  List<Widget> _weather(ThemeColors c) {
    return [
      _sunShape(x: 296, y: 34, size: 44),
      _cloud(left: 44, top: 110, w: 66, a: 0.55),
      _cloud(left: 156, top: 40, w: 96, a: 0.85),
      _cloud(left: 330, top: 120, w: 52, a: 0.4),
      // rain lines
      for (final (x, y) in const [(250.0, 96.0), (270.0, 126.0), (290.0, 100.0), (310.0, 140.0), (330.0, 108.0), (350.0, 138.0)])
        Positioned(
          left: x,
          top: y,
          child: Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: onDark ? _w(Colors.lightBlueAccent, 0.7) : const Color(0xFF5B9BD5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      _hill(left: -40, bottom: -30, w: 260, h: 140, color: onDark ? _deepGreen : _lightGreen, alpha: onDark ? 0.5 : 0.6),
      _hill(left: 180, bottom: -50, w: 300, h: 165, color: onDark ? _midGreen : _midGreen, alpha: onDark ? 0.55 : 0.8),
      _cropRow(left: 80, bottom: 52, stalks: 10),
      _tree(left: 330, bottom: 52),
      Positioned(top: 16, right: 20, child: Icon(Icons.wb_sunny, size: 30, color: onDark ? _w(_gold, 0.9) : _gold)),
    ];
  }

  List<Widget> _tools(ThemeColors c) {
    return [
      _cloud(left: 60, top: 56, w: 60),
      _sunShape(x: 300, y: 44, size: 44),
      _hill(left: -30, bottom: -40, w: 480, h: 160, color: onDark ? _midGreen : _lightGreen, alpha: onDark ? 0.5 : 0.7),
      // tool shed
      Positioned(
        left: 282,
        bottom: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 52,
              decoration: BoxDecoration(
                color: onDark ? const Color(0xFF2A3A30) : const Color(0xFF8A5A33),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                border: Border.all(color: onDark ? Colors.white24 : Colors.brown.shade300),
              ),
              child: Icon(Icons.garage_outlined, color: onDark ? _w(_gold, 0.8) : Colors.white, size: 26),
            ),
            Container(width: 92, height: 8, color: onDark ? const Color(0xFF3A2F14) : Colors.brown),
          ],
        ),
      ),
      Positioned(
        left: 74,
        bottom: 64,
        child: Icon(Icons.plumbing_rounded, color: onDark ? _w(Colors.white, 0.75) : const Color(0xFF4C6B8A), size: 42),
      ),
      Positioned(
        left: 130,
        bottom: 56,
        child: Icon(Icons.hardware_rounded, color: onDark ? _w(Colors.white, 0.7) : const Color(0xFF7A4A25), size: 40),
      ),
      Positioned(
        left: 204,
        bottom: 72,
        child: Icon(Icons.grass_rounded, color: onDark ? _w(_lightGreen, 0.9) : _midGreen, size: 40),
      ),
      Positioned(
        left: 248,
        bottom: 150,
        child: Icon(Icons.water_drop_rounded, color: onDark ? _w(Colors.lightBlueAccent, 0.8) : const Color(0xFF5B9BD5), size: 26),
      ),
    ];
  }

  List<Widget> _quality(ThemeColors c) {
    return [
      _cloud(left: 60, top: 46, w: 58),
      _sunShape(x: 306, y: 40, size: 46),
      _hill(left: -40, bottom: -40, w: 520, h: 170, color: onDark ? _midGreen : _lightGreen, alpha: onDark ? 0.5 : 0.7),
      // big leaf
      Positioned(
        left: 118,
        bottom: 60,
        child: Icon(Icons.eco_rounded, color: onDark ? _w(_lightGreen, 0.95) : _deepGreen, size: 120),
      ),
      // magnifier
      Positioned(
        left: 236,
        bottom: 96,
        child: Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: onDark ? _w(_gold, 0.95) : const Color(0xFFB07C44),
              width: 10,
            ),
          ),
        ),
      ),
      Positioned(
        left: 314,
        bottom: 84,
        child: Container(
          width: 12,
          height: 58,
          transform: Matrix4.rotationZ(0.7),
          decoration: BoxDecoration(
            color: onDark ? _w(_gold, 0.9) : const Color(0xFFB07C44),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      Positioned(
        left: 128,
        bottom: 150,
        child: Icon(Icons.check_circle_rounded, color: onDark ? _w(_gold, 0.95) : _gold, size: 30),
      ),
    ];
  }

  List<Widget> _trade(ThemeColors c) {
    return [
      _cloud(left: 44, top: 48, w: 62),
      _sunShape(x: 306, y: 40, size: 48),
      _hill(left: -30, bottom: -40, w: 500, h: 168, color: onDark ? _midGreen : _lightGreen, alpha: onDark ? 0.52 : 0.72),
      // grain sacks
      Positioned(
        left: 56,
        bottom: 70,
        child: Icon(Icons.inventory_2_rounded, color: onDark ? _w(_gold, 0.85) : _gold, size: 48),
      ),
      Positioned(
        left: 120,
        bottom: 58,
        child: Icon(Icons.inventory_2_rounded, color: onDark ? _w(Colors.white, 0.6) : const Color(0xFFB07C44), size: 54),
      ),
      // handshake / deal
      Positioned(
        left: 196,
        bottom: 84,
        child: Icon(Icons.handshake_rounded, color: onDark ? _w(_lightGreen, 0.95) : _deepGreen, size: 74),
      ),
      Positioned(
        left: 292,
        bottom: 70,
        child: Icon(Icons.payments_rounded, color: onDark ? _w(_gold, 0.9) : _gold, size: 40),
      ),
      Positioned(
        left: 322,
        bottom: 136,
        child: Icon(Icons.trending_up_rounded, color: onDark ? _w(Colors.white, 0.8) : _midGreen, size: 34),
      ),
    ];
  }

  List<Widget> _onboarding(ThemeColors c) {
    return [
      _sunShape(x: 330, y: 46, size: 48),
      _cloud(left: 70, top: 56, w: 60),
      _hill(left: -40, bottom: -20, w: 240, h: 140, color: onDark ? _deepGreen : _lightGreen, alpha: onDark ? 0.5 : 0.55),
      _hill(left: 170, bottom: -40, w: 290, h: 165, color: onDark ? _midGreen : _midGreen, alpha: onDark ? 0.55 : 0.85),
      _cropRow(left: 90, bottom: 62, stalks: 9),
      _cropRow(left: 246, bottom: 48, stalks: 8),
      _tree(left: 250, bottom: 56),
      if (onDark) Positioned(left: 30, bottom: 26, child: Icon(Icons.local_florist_rounded, size: 40, color: _w(_gold, 0.85)))
      else Positioned(left: 30, bottom: 26, child: Icon(Icons.local_florist_rounded, size: 40, color: _gold)),
    ];
  }
}