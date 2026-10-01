import 'package:flutter/widgets.dart';

/// Shared curves and durations so every transition in the app feels like it
/// came from the same hand.
class Motion {
  Motion._();

  // Durations. Micro-interactions sit in the 150–250ms band; anything longer
  // is a deliberate transition, not a hover reaction.
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration lazy = Duration(milliseconds: 600);

  /// Perceived latency budget before a loading state should appear.
  static const Duration loadingDelay = Duration(milliseconds: 250);

  /// Streaming caret blink.
  static const Duration caretBlink = Duration(milliseconds: 520);

  // Curves. `emphasized` is the default for anything the user initiated.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve standard = Curves.easeOutCubic;
  static const Curve decelerate = Curves.easeOutQuart;
  static const Curve springy = Cubic(0.34, 1.4, 0.64, 1.0);
  static const Curve exit = Curves.easeInCubic;
}

/// Reusable staggered reveal for lists and grids.
///
/// Children fade and lift in sequence. [step] is deliberately short: at 40ms
/// per item a 6-item grid resolves in a quarter second, which reads as
/// responsive rather than staged.
class StaggeredReveal extends StatelessWidget {
  final int index;
  final Duration step;
  final Widget child;

  const StaggeredReveal({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 40),
  });

  @override
  Widget build(BuildContext context) {
    final delay = step * index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.slow + delay,
      curve: Interval(
        // Compress the curve so the tail of the delay does not drag the
        // total duration past a quarter second.
        (delay.inMilliseconds /
                (Motion.slow.inMilliseconds + delay.inMilliseconds))
            .clamp(0.0, 0.85),
        1.0,
        curve: Motion.emphasized,
      ),
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
