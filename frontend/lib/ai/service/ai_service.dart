/// Client for the `/ai/chat` SSE endpoint.
///
/// The request is sent with `http.Client().send` and the response body is
/// decoded line by line. The server is always allowed to finish a reply, so
/// every terminal state is a real `MessageStatus` rather than a thrown
/// exception the UI has to interpret.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:jeevandhara2/ai/models/chat_message.dart';
import 'package:jeevandhara2/services/api_service.dart';

/// One decoded SSE event, in the shape the backend emits.
class AiEvent {
  const AiEvent(this.name, this.data);

  final String name;
  final Map<String, dynamic> data;
}

class AiException implements Exception {
  AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Incremental parser for a `text/event-stream` body.
///
/// Frames are separated by a blank line. `data:` lines are concatenated with a
/// newline per the SSE spec, and a single trailing space is stripped because
/// the server appends one to every token to keep reassembly lossless.
class SseParser {
  final _buffer = StringBuffer();
  String _eventName = 'message';
  final _dataLines = <String>[];

  /// Feeds a chunk and returns every complete event it unlocked.
  List<AiEvent> addChunk(String chunk) {
    _buffer.write(chunk);
    final events = <AiEvent>[];

    // Split on newlines but keep the tail: a chunk can end mid-frame.
    final text = _buffer.toString();
    final lines = text.split('\n');
    _buffer
      ..clear()
      ..write(lines.removeLast());

    for (final rawLine in lines) {
      final line = rawLine.endsWith('\r')
          ? rawLine.substring(0, rawLine.length - 1)
          : rawLine;

      if (line.isEmpty) {
        final event = _flush();
        if (event != null) events.add(event);
        continue;
      }
      if (line.startsWith(':')) continue; // comment / keep-alive

      final colon = line.indexOf(':');
      if (colon == -1) continue;
      final field = line.substring(0, colon);
      var value = line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);

      switch (field) {
        case 'event':
          _eventName = value;
        case 'data':
          _dataLines.add(value);
      }
    }

    return events;
  }

  /// Returns the pending event, if any. Called when the stream ends so a
  /// server that closes without a trailing blank line still yields its last
  /// frame.
  AiEvent? close() => _flush();

  AiEvent? _flush() {
    if (_dataLines.isEmpty) {
      _eventName = 'message';
      return null;
    }
    final name = _eventName;
    final payload = _dataLines.join('\n');
    _dataLines.clear();
    _eventName = 'message';

    if (name == 'done') {
      // The terminal frame carries no text the UI needs.
      return AiEvent(name, <String, dynamic>{});
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        return AiEvent(name, decoded.cast<String, dynamic>());
      }
    } on FormatException {
      // Fall through: a malformed frame should not kill the stream.
    }
    return null;
  }
}

/// Metadata about the backend assistant, used for the provider chip.
class AiCapabilities {
  const AiCapabilities({
    required this.provider,
    required this.llmConfigured,
    required this.gazetteer,
    required this.tools,
  });

  final String provider;
  final bool llmConfigured;
  final bool gazetteer;
  final List<Map<String, dynamic>> tools;

  factory AiCapabilities.fromJson(Map<String, dynamic> json) => AiCapabilities(
        provider: (json['provider'] ?? 'unknown').toString(),
        llmConfigured: json['llm_configured'] == true,
        gazetteer: json['gazetteer'] == true,
        tools: (json['tools'] as List?)
                ?.map((e) => (e as Map).cast<String, dynamic>())
                .toList() ??
            const [],
      );
}

class AiService {
  AiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiService.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  /// Location context sent with every turn so weather questions resolve
  /// without a second round trip.
  double? lat;
  double? lon;
  String placeName = '';

  /// True while a reply is streaming. The composer uses it to swap the send
  /// button for stop and to lock the input.
  bool isStreaming = false;

  AiCapabilities? _capabilities;
  AiCapabilities? get capabilities => _capabilities;

  /// Fetches the tool registry. Failure is non-fatal: the client keeps its
  /// built-in list, so the composer is never blocked on this call.
  Future<AiCapabilities> loadCapabilities() async {
    if (_capabilities != null) return _capabilities!;
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/ai/capabilities'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        _capabilities = AiCapabilities.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {
      // Offline. Callers fall back to the local registry.
    }
    return _capabilities ??
        const AiCapabilities(
          provider: 'offline',
          llmConfigured: false,
          gazetteer: false,
          tools: [],
        );
  }

  /// Sends a prompt and streams the reply into [message].
  ///
  /// [message] is mutated in place as tokens arrive, and [onProgress] is
  /// called after every event so the caller can repaint. The returned future
  /// completes when the server sends `done`; it does not throw on a stream
  /// error — the failure is recorded on the message instead, because a partial
  /// answer plus an error note is more useful to the user than a dropped turn.
  Future<void> streamReply({
    required String prompt,
    required ChatMessage message,
    void Function()? onProgress,
  }) async {
    final request = http.Request('POST', Uri.parse('$_baseUrl/ai/chat'))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode({
        'prompt': prompt,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (placeName.isNotEmpty) 'place_name': placeName,
      });

    isStreaming = true;
    try {
      final response = await _client.send(request);

      if (response.statusCode != 200) {
        // Drain the body so the error detail is available for the message.
        final body = await response.stream.bytesToString();
        message
          ..status = MessageStatus.failed
          ..thinkingLabel = '';
        message.text = _friendlyError(response.statusCode, body);
        return;
      }

      final parser = SseParser();
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        for (final event in parser.addChunk(chunk)) {
          _apply(event, message);
          onProgress?.call();
        }
      }
      // A server that closes the stream without a final blank line still has a
      // pending frame worth reading.
      final tail = parser.close();
      if (tail != null) {
        _apply(tail, message);
        onProgress?.call();
      }

      if (message.status == MessageStatus.streaming) {
        message.status = message.text.trim().isEmpty
            ? MessageStatus.failed
            : MessageStatus.complete;
        if (message.status == MessageStatus.failed) {
          message.text = 'The assistant stopped before sending a reply.';
        }
      }
    } on TimeoutException {
      message
        ..status = MessageStatus.failed
        ..thinkingLabel = ''
        ..text = 'The assistant took too long to respond. Please try again.';
    } catch (_) {
      message
        ..status = MessageStatus.failed
        ..thinkingLabel = ''
        ..text = 'Could not reach the assistant. Check your connection and '
            'try again.';
    } finally {
      isStreaming = false;
      message.thinkingLabel = '';
    }
  }

  void _apply(AiEvent event, ChatMessage message) {
    switch (event.name) {
      case 'status':
        message.thinkingLabel = (event.data['text'] ?? '').toString();
      case 'delta':
        message.appendDelta((event.data['text'] ?? '').toString());
      case 'citation':
        message.citations = [
          ...message.citations,
          Citation.fromJson(event.data),
        ];
      case 'tool':
        message.tools = [
          ...message.tools,
          ToolResult.fromJson(event.data),
        ];
      case 'done':
        if (message.status == MessageStatus.streaming) {
          message.status = MessageStatus.complete;
        }
    }
  }

  /// Maps transport failures onto something a farmer can act on, reusing the
  /// app's existing wording conventions.
  String _friendlyError(int statusCode, String body) {
    if (statusCode >= 500) {
      return 'The assistant is temporarily unavailable. Please try again.';
    }
    if (statusCode == 422) {
      return 'That message could not be understood. Please rephrase it.';
    }
    try {
      final detail = (jsonDecode(body) as Map)['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {
      // Fall through to the generic message.
    }
    return 'The assistant could not respond ($statusCode).';
  }

  void dispose() => _client.close();
}
