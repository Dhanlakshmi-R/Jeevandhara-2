import 'package:flutter/material.dart';

import 'package:jeevandhara2/design/tokens.dart';
import 'package:jeevandhara2/design/typography.dart';
import 'package:jeevandhara2/theme/colors.dart';

/// The chat input.
///
/// Grows with its content up to a ceiling, then scrolls. The send button sits
/// inside the field rather than beside it, which keeps the composer one object
/// visually and leaves the thumb a larger target.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.enabled = true,
    this.busy = false,
    this.hint = 'Ask about weather, prices, buyers or your crops',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final bool enabled;
  final bool busy;
  final String hint;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  static const _maxLines = 6;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  void _onChanged() {
    // Only the send button's enabled state depends on the text, so rebuild
    // rather than the whole composer.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.busy || !widget.enabled) return;
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend();
    // Keep focus so a follow-up question can be typed straight away.
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasText = widget.controller.text.trim().isNotEmpty;
    final canSend = hasText && !widget.busy && widget.enabled;

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.rLg,
        border: Border.all(color: c.divider),
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 168),
            child: Scrollbar(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: _maxLines,
                style: AppType.composer(context),
                cursorColor: c.accent,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                // Enter inserts a newline, matching every other chat app.
                // Send stays on the button so a multi-line question about a
                // list of crops is not cut off at the first line.
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: AppType.composer(context).copyWith(
                    color: c.textSecondary.withValues(alpha: 0.75),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isCollapsed: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              if (widget.onAttach != null)
                _CircleButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Attach a tool',
                  onTap: widget.onAttach,
                ),
              const Spacer(),
              AnimatedScale(
                scale: canSend ? 1 : 0.85,
                duration: Motion.fast,
                curve: Motion.emphasized,
                child: Opacity(
                  opacity: canSend ? 1 : 0.5,
                  child: _SendButton(
                    busy: widget.busy,
                    onTap: canSend ? _submit : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: busy ? 'Waiting for reply' : 'Send message',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
            ),
            child: Icon(
              busy ? Icons.more_horiz_rounded : Icons.arrow_upward_rounded,
              size: 19,
              color: c.textOnPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 20, color: c.textSecondary),
          ),
        ),
      ),
    );
  }
}
