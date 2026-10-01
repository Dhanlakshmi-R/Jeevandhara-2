import 'package:flutter/material.dart';

import 'package:jeevandhara2/design/tokens.dart';
import 'package:jeevandhara2/design/typography.dart';
import 'package:jeevandhara2/theme/colors.dart';

/// Three dots that breathe while the assistant is thinking.
///
/// A single 900ms controller drives all three dots with a phase offset rather
/// than three separate animations, so they cannot drift apart and there is
/// only one ticker to dispose.
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key, this.label = '', this.compact = false});

  /// The current `status` line from the stream, shown beside the dots.
  final String label;
  final bool compact;

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_controller.value + i * 0.22) % 1.0;
                // A quick rise, a slow fall, so the loop reads as continuous.
                final wave = t < 0.5
                    ? Curves.easeOut.transform(t * 2)
                    : 1 - Curves.easeIn.transform((t - 0.5) * 2);
                return Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
                  child: Transform.translate(
                    offset: Offset(0, -2.5 * wave),
                    child: Container(
                      width: widget.compact ? 5 : 6,
                      height: widget.compact ? 5 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.textSecondary.withValues(
                          alpha: 0.35 + 0.55 * wave,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
        if (widget.label.isNotEmpty) ...[
          const SizedBox(width: Gap.md),
          Flexible(
            child: AnimatedSwitcher(
              duration: Motion.fast,
              child: Text(
                widget.label,
                key: ValueKey(widget.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.meta(context),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
