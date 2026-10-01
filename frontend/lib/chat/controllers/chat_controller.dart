import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:jeevandhara2/ai/data/chat_repository.dart';
import 'package:jeevandhara2/ai/models/chat_message.dart';
import 'package:jeevandhara2/ai/prompt/ai_context.dart';
import 'package:jeevandhara2/ai/service/ai_service.dart';

/// Owns the conversation for the chat surface.
///
/// The screen is a pure view over this: it sends prompts and renders whatever
/// is in [messages]. Streaming mutates a single in-flight [ChatMessage] in
/// place, and the screen listens to [messages] to know what to repaint, which
/// keeps token-by-token updates to one `notifyListeners` per frame rather than
/// a new list per token.
class ChatController extends ChangeNotifier {
  ChatController({
    AiService? service,
    ChatRepository? repository,
    AiContext? context,
  })  : _service = service ?? AiService(),
        _repository = repository ?? ChatRepository(),
        _context = context ?? AiContext() {
    // Push the stored location into the service so weather questions resolve.
    _service.lat = _context.lat;
    _service.lon = _context.lon;
    _service.placeName = _context.placeName;
  }

  final AiService _service;
  final ChatRepository _repository;
  final AiContext _context;

  ChatSession _session = ChatSession.fresh();
  List<ChatMessage> get messages => _session.messages;

  String _draft = '';
  String get draft => _draft;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  bool _isReady = false;
  bool get isReady => _isReady;

  bool _hasLocation = false;
  bool get hasLocation => _hasLocation;

  /// Name of the place the weather tool will use. Empty until a location has
  /// been picked in the Weather flow.
  String get placeName => _context.placeName;

  /// Set when a turn could not be completed, so the screen can offer a retry
  /// without re-parsing the last message.
  String? _error;

  String? get error => _error;

  AiCapabilities? get capabilities => _service.capabilities;

  /// Restores the last conversation and the location context.
  ///
  /// Wrapped in its own try/catch: a storage failure must still land the user
  /// on a usable empty chat rather than an error screen.
  Future<void> init() async {
    try {
      await _context.load();
      _hasLocation = _context.hasLocation;
      _service
        ..lat = _context.lat
        ..lon = _context.lon
        ..placeName = _context.placeName;

      final activeId = await _repository.loadActiveSessionId();
      if (activeId != null) {
        final saved = await _repository.loadSession(activeId);
        if (saved != null) {
          _session = saved;
          // A transcript restored from disk is never mid-flight: any turn that
          // was streaming when the app died was rewritten to failed on load,
          // so it can be retried or cleared from the UI.
          notifyListeners();
          _isReady = true;
          return;
        }
      }
    } catch (_) {
      // Start fresh.
    }
    _isReady = true;
    notifyListeners();
  }

  /// Fetches backend capabilities. Kept separate from [init] because it is a
  /// network call the chat surface does not need in order to be usable.
  Future<void> loadCapabilities() async {
    await _service.loadCapabilities();
    notifyListeners();
  }

  bool get isEmpty => _session.messages.isEmpty;

  bool get canSend => _draft.trim().isNotEmpty && !_isBusy;

  void updateDraft(String value) {
    if (_draft == value) return;
    _draft = value;
    notifyListeners();
  }

  /// Appends the user's turn, starts streaming, and persists when it lands.
  Future<void> send(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty || _isBusy) return;

    _error = null;
    _draft = '';

    final userMessage = ChatMessage.user(trimmed);
    final assistantMessage = ChatMessage(
      role: ChatRole.assistant,
      text: '',
      status: MessageStatus.streaming,
    );

    _session.messages.addAll([userMessage, assistantMessage]);
    _isBusy = true;
    // Two notifications, not one per token: repaint the list with the new
    // turn, then let each token repaint only the streaming bubble.
    notifyListeners();

    try {
      // Repaint per token: the streaming bubble grows as the answer arrives.
      // Only the last message changes, so this stays cheap even at 45 deltas
      // per second.
      await _service.streamReply(
        prompt: trimmed,
        message: assistantMessage,
        onProgress: notifyListeners,
      );
    } finally {
      _isBusy = false;
      _session = _session.copyWith(messages: _session.messages);
      notifyListeners();
    }

    if (assistantMessage.status == MessageStatus.failed) {
      _error = assistantMessage.text;
    }

    await _persist();
  }

  /// Abandons a failed turn: the placeholder bubble is dropped and the prompt
  /// is put back so the user can edit and resend rather than retype.
  Future<void> retryLastFailed() async {
    final index = _session.messages.lastIndexWhere(
      (m) => !m.isUser && m.status == MessageStatus.failed,
    );
    if (index <= 0) return;

    // The matching prompt is the user turn immediately before it.
    final prompt = _session.messages[index - 1].text;
    _session.messages.removeRange(index - 1, index + 1);
    _error = null;
    notifyListeners();
    await send(prompt);
  }

  /// Clears a failed bubble without resending. The user turn stays, so the
  /// transcript still shows what was asked.
  void dismissError() {
    _session.messages.removeWhere(
      (m) => !m.isUser && m.status == MessageStatus.failed,
    );
    _error = null;
    notifyListeners();
  }

  /// Starts a new conversation, persisting the current one first so it is not
  /// lost when the user taps "new chat".
  Future<void> newConversation() async {
    if (_isBusy) return;
    await _persist();
    _session = ChatSession.fresh();
    _error = null;
    notifyListeners();
  }

  Future<void> openSession(ChatSession session) async {
    if (_isBusy) return;
    await _persist();
    _session = session;
    _error = null;
    notifyListeners();
  }

  Future<List<ChatSession>> recentSessions() => _repository.loadRecent();

  /// Re-reads the location after the user picked one elsewhere in the app.
  /// Called when the chat screen becomes visible again.
  Future<void> refreshLocation() async {
    await _context.load();
    _hasLocation = _context.hasLocation;
    _service
      ..lat = _context.lat
      ..lon = _context.lon
      ..placeName = _context.placeName;
    notifyListeners();
  }

  Future<void> _persist() async {
    if (_session.messages.isEmpty) return;
    try {
      _session = _session.copyWith(messages: _session.messages);
      await _repository.saveSession(_session);
      await _repository.saveActiveSessionId(_session.id);
    } catch (_) {
      // Losing history is not worth interrupting the conversation for.
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
