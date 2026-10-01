/// Data model for a single chat message.
///
/// One class covers both roles rather than a sealed hierarchy, because the
/// transcript only ever reads it and the streaming path mutates a single
/// in-flight assistant turn in place. A subclass would add ceremony without
/// changing any behaviour.
library;

import 'dart:convert';

enum ChatRole { user, assistant }

/// Where a claim in the assistant's answer came from.
class Citation {
  const Citation({
    required this.label,
    this.kind = 'source',
    this.detail = '',
  });

  final String label;

  /// `weather`, `price`, `source` or `app`. Drives the chip's accent.
  final String kind;
  final String detail;

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
        label: (json['label'] ?? '').toString(),
        kind: (json['kind'] ?? 'source').toString(),
        detail: (json['detail'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'kind': kind,
        'detail': detail,
      };
}

/// An inline result card the assistant asked the backend to render, such as
/// the current-weather summary. `payload` is intentionally untyped: the
/// widgets switch on `tool` to decide how to lay it out.
class ToolResult {
  const ToolResult({
    required this.tool,
    required this.title,
    this.payload = const {},
  });

  final String tool;
  final String title;
  final Map<String, dynamic> payload;

  factory ToolResult.fromJson(Map<String, dynamic> json) => ToolResult(
        tool: (json['tool'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  Map<String, dynamic> toJson() => {
        'tool': tool,
        'title': title,
        'payload': payload,
      };
}

/// Lifecycle of an assistant turn.
///
/// `failed` is terminal too — it renders a retry affordance rather than the
/// streaming caret, so the UI can switch on a closed set of end states.
enum MessageStatus { complete, streaming, failed }

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    this.status = MessageStatus.complete,
    this.citations = const [],
    this.tools = const [],
    this.thinkingLabel = '',
    this.createdAt,
  });

  factory ChatMessage.user(String text, {DateTime? createdAt}) => ChatMessage(
        role: ChatRole.user,
        text: text,
        createdAt: createdAt ?? DateTime.now(),
      );

  /// Builds a turn from a persisted record, restoring whatever was mid-flight
  /// when the app was last closed. An interrupted [MessageStatus.streaming]
  /// is deliberately downgraded to [MessageStatus.failed] so a killed process
  /// cannot leave a permanent spinner on the next launch.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final role =
        (json['role'] == 'assistant') ? ChatRole.assistant : ChatRole.user;
    var status = MessageStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => MessageStatus.complete,
    );
    if (role == ChatRole.assistant && status == MessageStatus.streaming) {
      status = MessageStatus.failed;
    }
    final raw = json['created_at'];
    return ChatMessage(
      role: role,
      text: (json['text'] ?? '').toString(),
      status: status,
      citations: (json['citations'] as List?)
              ?.map(
                  (e) => Citation.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      tools: (json['tools'] as List?)
              ?.map((e) =>
                  ToolResult.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      thinkingLabel: (json['thinking_label'] ?? '').toString(),
      createdAt:
          raw is num ? DateTime.fromMillisecondsSinceEpoch(raw.toInt()) : null,
    );
  }

  final ChatRole role;

  /// Mutable: the streaming path appends tokens in place and the error paths
  /// replace it wholesale. Making it a field rather than a getter keeps the
  /// transcript a single object per turn.
  String text;
  MessageStatus status;
  List<Citation> citations;
  List<ToolResult> tools;

  /// Current line in the thinking indicator, e.g. "Checking rain risk".
  String thinkingLabel;
  final DateTime? createdAt;

  bool get isUser => role == ChatRole.user;
  bool get isStreaming => status == MessageStatus.streaming;

  /// Appends a streamed token. The backend splits on whitespace and includes
  /// the trailing space, so a plain concatenation reassembles the text
  /// exactly.
  void appendDelta(String delta) {
    if (delta.isEmpty) return;
    text += delta;
  }

  /// True when a failed turn carries no answer, i.e. there is nothing to keep
  /// and the bubble should render as a pure error state.
  bool get isEmptyFailure =>
      status == MessageStatus.failed && text.trim().isEmpty;

  ChatMessage copyWith({
    String? text,
    MessageStatus? status,
    List<Citation>? citations,
    List<ToolResult>? tools,
    String? thinkingLabel,
  }) =>
      ChatMessage(
        role: role,
        text: text ?? this.text,
        status: status ?? this.status,
        citations: citations ?? this.citations,
        tools: tools ?? this.tools,
        thinkingLabel: thinkingLabel ?? this.thinkingLabel,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'text': text,
        'status': status.name,
        'citations': citations.map((c) => c.toJson()).toList(),
        'tools': tools.map((t) => t.toJson()).toList(),
        'thinking_label': thinkingLabel,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  @override
  String toString() => jsonEncode(toJson());
}

/// A persisted conversation.
class ChatSession {
  ChatSession({
    required this.id,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
  });

  factory ChatSession.fresh() {
    final now = DateTime.now();
    return ChatSession(
      id: 'session_${now.millisecondsSinceEpoch}',
      messages: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ChatSession(
      id: (json['id'] ?? 'session_unknown').toString(),
      messages: (json['messages'] as List?)
              ?.map((e) =>
                  ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['created_at'] as num?)?.toInt() ?? now.millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updated_at'] as num?)?.toInt() ?? now.millisecondsSinceEpoch,
      ),
      title: (json['title'] ?? '').toString(),
    );
  }

  final String id;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Derived from the first user message so the history list needs no
  /// separate write path.
  String title;

  String get displayTitle {
    if (title.isNotEmpty) return title;
    final firstUser = messages.where((m) => m.isUser).firstOrNull;
    if (firstUser == null) return 'New conversation';
    final flat = firstUser.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return flat.length <= 48 ? flat : '${flat.substring(0, 47)}…';
  }

  ChatSession copyWith({List<ChatMessage>? messages, DateTime? updatedAt}) =>
      ChatSession(
        id: id,
        messages: messages ?? this.messages,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        title: title,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'messages': messages.map((m) => m.toJson()).toList(),
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'title': title,
      };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
