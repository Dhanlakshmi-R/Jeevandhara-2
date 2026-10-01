import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:jeevandhara2/ai/models/chat_message.dart';
import 'package:jeevandhara2/ai/prompt/tool_registry.dart';
import 'package:jeevandhara2/chat/widgets/assistant_text.dart';
import 'package:jeevandhara2/chat/widgets/citation_chips.dart';
import 'package:jeevandhara2/chat/widgets/thinking_indicator.dart';
import 'package:jeevandhara2/chat/widgets/tool_result_card.dart';
import 'package:jeevandhara2/design/palette.dart';
import 'package:jeevandhara2/design/tokens.dart';
import 'package:jeevandhara2/design/typography.dart';

/// A single turn in the transcript.
///
/// User turns sit right-aligned in a tinted pill; assistant turns sit
/// full-width because answers are read rather than scanned, and they carry the
/// tool cards and citation chips. Copy is offered on both so a farmer can
/// paste an answer into a message to a buyer.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onDismissError,
    this.onOpenTool,
  });

  final ChatMessage message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismissError;
  final void Function(AiTool tool)? onOpenTool;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) return _UserTurn(message: message);
    return _AssistantTurn(
      message: message,
      onRetry: onRetry,
      onDismissError: onDismissError,
      onOpenTool: onOpenTool,
    );
  }
}

class _UserTurn extends StatelessWidget {
  const _UserTurn({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: Gap.md,
              ),
              decoration: BoxDecoration(
                color: context.ai.userBubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(Radii.lg),
                  topRight: Radius.circular(Radii.xs),
                  bottomLeft: Radius.circular(Radii.lg),
                  bottomRight: Radius.circular(Radii.lg),
                ),
                border: Border.all(color: context.ai.userBubbleBorder),
              ),
              child: Text(message.text, style: AppType.userTurn(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantTurn extends StatelessWidget {
  const _AssistantTurn({
    required this.message,
    this.onRetry,
    this.onDismissError,
    this.onOpenTool,
  });

  final ChatMessage message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismissError;
  final void Function(AiTool tool)? onOpenTool;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (message.isEmptyFailure) {
      return _ErrorNotice(
        message: message.text,
        onRetry: onRetry,
        onDismiss: onDismissError,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(busy: message.isStreaming),
              const SizedBox(width: Gap.sm),
              Text('Assistant', style: AppType.label(context)),
            ],
          ),
          const SizedBox(height: Gap.sm),
          // Indent past the avatar so the answer aligns with the label rather
          // than with the icon.
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.text.isNotEmpty)
                  AssistantText(text: message.text)
                else
                  ThinkingIndicator(label: message.thinkingLabel),
                for (final tool in message.tools) ...[
                  const SizedBox(height: Gap.md),
                  ToolResultCard(tool: tool, onOpen: onOpenTool),
                ],
                if (message.citations.isNotEmpty) ...[
                  const SizedBox(height: Gap.md),
                  CitationChips(citations: message.citations),
                ],
                if (!message.isStreaming && message.text.isNotEmpty) ...[
                  const SizedBox(height: Gap.xs),
                  _TurnActions(
                    text: message.text,
                    failed: message.status == MessageStatus.failed,
                    onRetry: onRetry,
                  ),
                ],
              ],
            ),
          ),
          // Blinking caret. Sized 0 wide and 0 opaque when not streaming so it
          // does not occupy a gap in the layout.
          if (message.isStreaming)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 4),
              child: _Caret(color: c.primary),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: Icon(Icons.auto_awesome_rounded, size: 14, color: c.textOnPrimary),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret({required this.color});

  final Color color;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: 2,
        height: 16,
        color: widget.color.withValues(alpha: 0.35 + 0.65 * _controller.value),
      ),
    );
  }
}

class _TurnActions extends StatelessWidget {
  const _TurnActions({required this.text, required this.failed, this.onRetry});

  final String text;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MiniAction(
          icon: Icons.copy_rounded,
          tooltip: 'Copy answer',
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Answer copied'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
        if (failed) ...[
          const SizedBox(width: Gap.xs),
          _MiniAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Try again',
            onTap: onRetry,
          ),
        ],
      ],
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.rSm,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 15, color: context.colors.textSecondary),
        ),
      ),
    );
  }
}

/// Failure state for a turn that produced no answer at all.
class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, this.onRetry, this.onDismiss});

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.lg),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.08),
        borderRadius: Radii.rMd,
        border: Border.all(color: c.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 17, color: c.warning),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppType.answer(context).copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: c.accent,
                ),
              ),
              TextButton(
                onPressed: onDismiss,
                style:
                    TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
