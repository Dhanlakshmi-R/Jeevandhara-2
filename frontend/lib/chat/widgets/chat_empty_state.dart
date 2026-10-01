import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:jeevandhara2/design/palette.dart';
import 'package:jeevandhara2/design/tokens.dart';
import 'package:jeevandhara2/design/typography.dart';

/// The empty state: an aurora, the greeting, and something to tap.
///
/// The aurora is three soft radial blobs on one slow 24s rotation. It is the
/// only animated background in the app and it is skipped entirely when the
/// user has reduced motion on, so it costs nothing for the people least able
/// to sit through it.
class ChatEmptyState extends StatefulWidget {
  const ChatEmptyState({
    super.key,
    required this.greeting,
    required this.lede,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  final String greeting;
  final String lede;
  final List<Widget> suggestions;
  final void Function(int index) onSuggestionTap;

  @override
  State<ChatEmptyState> createState() => _ChatEmptyStateState();
}

class _ChatEmptyStateState extends State<ChatEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void initState() {
    super.initState();
    // One revolution, not a loop: a looping gradient drifts perceptibly and
    // draws the eye away from the suggestions. Checked after the first frame
    // because `context` is not safe to read from `initState` for inherited
    // widgets like MediaQuery.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _AuroraPainter(
                  palette: context.ai,
                  progress: _controller.value,
                ),
              ),
            ),
          ),
        ),
        ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.gutter,
            Gap.xl,
            Gap.gutter,
            Gap.gutter,
          ),
          children: [
            const SizedBox(height: Gap.xxl),
            Text(widget.greeting, style: AppType.greeting(context)),
            const SizedBox(height: Gap.sm),
            Text(widget.lede, style: AppType.lede(context)),
            const SizedBox(height: Gap.xl),
            Text('Try asking', style: AppType.label(context)),
            const SizedBox(height: Gap.md),
            for (var i = 0; i < widget.suggestions.length; i++) ...[
              StaggeredReveal(
                index: i,
                step: const Duration(milliseconds: 55),
                child: widget.suggestions[i],
              ),
              if (i != widget.suggestions.length - 1)
                const SizedBox(height: Gap.sm),
            ],
          ],
        ),
      ],
    );
  }
}

/// Three blurred colour fields, rotated and offset by [progress].
class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.palette, required this.progress});

  final AiPalette palette;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // One full turn over the animation, so the field drifts in a circle and
    // returns exactly to its start.
    final angle = progress * 2 * math.pi;
    final dx = 0.06 * math.cos(angle);
    final dy = 0.06 * math.sin(angle);
    final paint = Paint()..blendMode = BlendMode.plus;

    // Only three of the four aurora hues, and they move in opposition, so the
    // mesh never collapses to a single dominant wash.
    final hues = palette.aurora;
    void blob(
        Color color, double cx, double cy, double radius, double opacity) {
      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(cx * size.width, cy * size.height),
        radius * size.shortestSide,
        paint,
      );
    }

    blob(hues[0], 0.22 + dx, 0.18 + dy, 0.55, palette.isDark ? 0.14 : 0.05);
    blob(hues[1], 0.82 - dx, 0.30 + dy * 0.6, 0.50,
        palette.isDark ? 0.12 : 0.04);
    blob(hues[3], 0.52 - dy, 0.72 - dx, 0.58, palette.isDark ? 0.10 : 0.035);
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.palette != palette;
}

/// A tappable suggestion chip row.
class SuggestionTile extends StatelessWidget {
  const SuggestionTile({
    super.key,
    required this.label,
    required this.prompt,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String prompt;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.rMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.md,
          ),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.72),
            borderRadius: Radii.rMd,
            border: Border.all(color: c.divider),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: c.accent),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  prompt,
                  style: AppType.answer(context).copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Icon(Icons.north_east_rounded, size: 14, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
