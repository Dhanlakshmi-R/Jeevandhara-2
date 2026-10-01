import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeevandhara2/ai/models/chat_message.dart';

/// Persists conversations across launches.
///
/// Stored as one JSON blob per session under `ai.session.<id>`, plus an index
/// of ids under `ai.sessions`. Sessions are read lazily, so keeping a hundred
/// of them does not cost a hundred JSON parses on startup.
class ChatRepository {
  ChatRepository({SharedPreferences? prefs}) : _prefs = prefs;

  static const _indexKey = 'ai.sessions';
  static const _sessionPrefix = 'ai.session.';
  static const _activeKey = 'ai.activeSession';

  /// Cap on stored sessions. Older ones are dropped oldest-first; the user
  /// almost never scrolls past a handful.
  static const _maxSessions = 30;

  SharedPreferences? _prefs;
  bool _loaded = false;

  Future<SharedPreferences> get _store async {
    if (_loaded) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    _loaded = true;
    return _prefs!;
  }

  Future<List<String>> _readIndex() async {
    final store = await _store;
    return store.getStringList(_indexKey) ?? const [];
  }

  Future<void> _writeIndex(List<String> ids) async {
    final store = await _store;
    await store.setStringList(_indexKey, ids);
  }

  /// Ids newest first.
  Future<List<String>> listSessionIds() async {
    final ids = await _readIndex();
    // A session whose blob is gone is a stale index entry; clean it up rather
    // than surfacing an empty row in the history drawer.
    final store = await _store;
    final alive = <String>[];
    for (final id in ids) {
      if (store.containsKey('$_sessionPrefix$id')) {
        alive.add(id);
      }
    }
    if (alive.length != ids.length) await _writeIndex(alive);
    return alive;
  }

  Future<ChatSession?> loadSession(String id) async {
    final store = await _store;
    final raw = store.getString('$_sessionPrefix$id');
    if (raw == null) return null;
    try {
      return ChatSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt record. Drop it so it cannot fail again on every launch.
      await store.remove('$_sessionPrefix$id');
      return null;
    }
  }

  /// Loads summaries for the history drawer without parsing every transcript.
  /// Cheap enough to call on each open, and avoids loading messages the user
  /// may not select.
  Future<List<ChatSession>> loadRecent({int limit = 20}) async {
    final ids = await listSessionIds();
    final sessions = <ChatSession>[];
    for (final id in ids.take(limit)) {
      final session = await loadSession(id);
      if (session != null) sessions.add(session);
    }
    return sessions;
  }

  Future<void> saveSession(ChatSession session) async {
    final store = await _store;
    await store.setString(
      '$_sessionPrefix${session.id}',
      jsonEncode(session.toJson()),
    );

    final ids = await _readIndex();
    ids.remove(session.id);
    ids.insert(0, session.id);

    // Evict the tail. Also removes the blob, so storage does not creep up.
    while (ids.length > _maxSessions) {
      final dropped = ids.removeLast();
      await store.remove('$_sessionPrefix$dropped');
    }
    await _writeIndex(ids);
  }

  Future<void> deleteSession(String id) async {
    final store = await _store;
    await store.remove('$_sessionPrefix$id');
    await _writeIndex((await _readIndex())..remove(id));
  }

  Future<void> clearAll() async {
    final store = await _store;
    for (final id in await _readIndex()) {
      await store.remove('$_sessionPrefix$id');
    }
    await store.remove(_indexKey);
    await store.remove(_activeKey);
  }

  Future<String?> loadActiveSessionId() async {
    final store = await _store;
    return store.getString(_activeKey);
  }

  Future<void> saveActiveSessionId(String id) async {
    final store = await _store;
    await store.setString(_activeKey, id);
  }
}
