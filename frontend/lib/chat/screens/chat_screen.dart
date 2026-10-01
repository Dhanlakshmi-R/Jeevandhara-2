import 'package:flutter/material.dart';

import 'package:jeevandhara2/ai/models/chat_message.dart';
import 'package:jeevandhara2/ai/prompt/prompt_suggestions.dart';
import 'package:jeevandhara2/ai/prompt/tool_registry.dart';
import 'package:jeevandhara2/chat/controllers/chat_controller.dart';
import 'package:jeevandhara2/chat/widgets/chat_composer.dart';
import 'package:jeevandhara2/chat/widgets/chat_empty_state.dart';
import 'package:jeevandhara2/chat/widgets/message_bubble.dart';
import 'package:jeevandhara2/design/tokens.dart';
import 'package:jeevandhara2/design/typography.dart';
import 'package:jeevandhara2/theme/colors.dart';

/// The conversation surface.
///
/// This is the app's home for both roles. The controller owns the transcript;
/// this widget only renders it and forwards intent, which is what keeps the
/// farmer and trader shells from needing two different chat implementations.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.controller,
    this.onOpenTool,
    this.headerTitle,
    this.visibleEpoch = 0,
  });

  /// Injected in tests; a fresh controller is created otherwise.
  final ChatController? controller;

  /// Called when a tool card or suggestion asks to open a feature screen.
  final void Function(AiTool tool)? onOpenTool;

  /// Overrides the title shown in the top bar. The shell supplies it so the
  /// same screen works under the farmer and trader shells.
  final String? headerTitle;

  /// Bumped by the shell each time the chat becomes the visible destination.
  ///
  /// This screen stays mounted underneath the shell, so nothing else tells it
  /// the user has been away picking a new place on the Weather screen. Without
  /// this the assistant would keep answering about the previous village.
  final int visibleEpoch;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _controller = widget.controller ?? ChatController();
  late final bool _ownsController = widget.controller == null;

  final _scrollController = ScrollController();
  final _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    // Kick off restore + capability fetch. Both are non-fatal; the chat is
    // usable before either resolves.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.init();
      if (mounted) await _controller.loadCapabilities();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The user may have picked a location in another tab while this screen
    // was still mounted underneath the shell. Guarded to the first pass:
    // `didChangeDependencies` also fires on unrelated inherited changes, and
    // re-reading storage on each of those is wasted work.
    if (_didRefreshLocation) return;
    _didRefreshLocation = true;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _controller.refreshLocation());
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Returning to the chat is the moment the stored place may have changed.
    if (widget.visibleEpoch != oldWidget.visibleEpoch) {
      _controller.refreshLocation();
    }
  }

  bool _didRefreshLocation = false;
  int _lastMessageCount = 0;
  String _lastDraft = '';

  void _onControllerChanged() {
    // Auto-scroll only when the transcript actually grew or the user sent
    // something. Scrolling on every streamed token fights a user reading up
    // the thread.
    final count = _controller.messages.length;
    final grew = count != _lastMessageCount;
    final sent = _lastDraft.isNotEmpty && _controller.draft.isEmpty;
    _lastMessageCount = count;
    _lastDraft = _controller.draft;

    if (grew || sent) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
    if (mounted) setState(() {});
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _scrollController.dispose();
    _inputController.dispose();
    // Only tear down a controller this screen created; an injected one
    // outlives the test.
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      children: [
        Expanded(
          child: _controller.isEmpty ? _buildEmpty(c) : _buildTranscript(),
        ),
        _buildComposerBar(c),
      ],
    );
  }

  Widget _buildEmpty(ThemeColors c) {
    final suggestions =
        PromptSuggestion.forContext(hasLocation: _controller.hasLocation);

    return ChatEmptyState(
      greeting: _greeting(),
      lede: _controller.hasLocation
          ? 'I can see you are in ${_controller.placeName}. '
              'Ask me anything, or pick one of these to start.'
          : 'I can check live weather, talk through market prices, find buyers '
              'near you, and open your crops, rental and quality tools.',
      suggestions: [
        for (final suggestion in suggestions)
          SuggestionTile(
            label: suggestion.label,
            prompt: suggestion.prompt,
            icon: suggestion.icon,
            onTap: () => _controller.send(suggestion.prompt),
          ),
      ],
      onSuggestionTap: (index) => _controller.send(suggestions[index].prompt),
    );
  }

  Widget _buildTranscript() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        Gap.gutter,
        Gap.lg,
        Gap.gutter,
        Gap.lg,
      ),
      itemCount: _controller.messages.length,
      itemBuilder: (context, index) {
        final message = _controller.messages[index];
        return MessageBubble(
          key: ValueKey(
              '${_controller.messages.length}-$index-${message.role.name}'),
          message: message,
          onRetry: message.status == MessageStatus.failed
              ? _controller.retryLastFailed
              : null,
          onDismissError: _controller.dismissError,
          onOpenTool: widget.onOpenTool,
        );
      },
    );
  }

  Widget _buildComposerBar(ThemeColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.background.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: c.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        Gap.gutter,
        Gap.md,
        Gap.gutter,
        Gap.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ChatComposer(
            controller: _inputController,
            busy: _controller.isBusy,
            onSend: () => _controller.send(_inputController.text),
            onAttach: () => _showToolSheet(context),
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return '$part. How can I help?';
  }

  /// Attaching a tool seeds the composer with a starter question rather than
  /// navigating away, so the answer arrives in the conversation where the
  /// rest of the context is.
  void _showToolSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ToolSheet(
        onPick: (tool) {
          Navigator.of(context).pop();
          _inputController.text = tool.promptHint;
          _inputController.selection = TextSelection.collapsed(
            offset: _inputController.text.length,
          );
        },
      ),
    );
  }
}

class _ToolSheet extends StatelessWidget {
  const _ToolSheet({required this.onPick});

  final void Function(AiTool tool) onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.all(Gap.md),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.rLg,
        border: Border.all(color: c.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ask about a tool', style: AppType.answer(context)),
          const SizedBox(height: Gap.md),
          for (final tool in AiTool.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(tool.icon, size: 19, color: c.accent),
              title: Text(tool.label,
                  style: AppType.answer(context).copyWith(fontSize: 14)),
              subtitle: Text(tool.promptHint, style: AppType.meta(context)),
              onTap: () => onPick(tool),
            ),
        ],
      ),
    );
  }
}
