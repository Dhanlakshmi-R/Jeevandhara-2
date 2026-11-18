import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the `exp` claim (seconds since the Unix epoch) out of a JWT.
///
/// Pure and tolerant: a token that is not a three-part JWT, or whose payload is
/// not decodable JSON, simply yields `null` rather than throwing. The app never
/// trusts this value for security — the server re-checks every token — it only
/// decides whether a silent refresh is worth attempting before a request.
DateTime? decodeJwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final decoded = jsonDecode(payload);
    if (decoded is! Map) return null;
    final exp = decoded['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// The single place session material is persisted.
///
/// The refresh token — the only long-lived secret the app holds — is kept in the
/// OS keystore through [FlutterSecureStorage] (Android Keystore, iOS Keychain,
/// Windows Credential Manager, web crypto). **A password is never stored here,
/// or anywhere else.** The app keeps a *token*, never a credential.
///
/// The short-lived access token and small non-secret preferences (the
/// remember-me choice, the sign-in identifier used only to pre-fill the form,
/// and the last-known role for fast routing) live in [SharedPreferences].
///
/// Everything is in-memory first, so a device with no keystore (a desktop test,
/// or an unsupported platform) degrades to a session that lasts only this run
/// instead of crashing.
class SessionStore {
  SessionStore._();

  static const _accessKey = 'auth_token';
  static const _roleKey = 'user_role';
  static const _rememberKey = 'remember_me';
  static const _identifierKey = 'remembered_identifier';
  static const _refreshKey = 'jj_refresh_token';

  static const _secure = FlutterSecureStorage(aOptions: AndroidOptions());

  static String? _accessToken;
  static DateTime? _accessExpiry;
  static String? _refreshToken;
  static bool _remember = true;

  /// Loads whatever survived the last run. Safe to call more than once.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _remember = prefs.getBool(_rememberKey) ?? true;
    _setAccessToken(prefs.getString(_accessKey));
    try {
      _refreshToken = await _secure.read(key: _refreshKey);
    } catch (_) {
      // No keystore available: stay signed out rather than crash.
      _refreshToken = null;
    }
  }

  static void _setAccessToken(String? token) {
    _accessToken = (token == null || token.isEmpty) ? null : token;
    _accessExpiry =
        _accessToken == null ? null : decodeJwtExpiry(_accessToken!);
  }

  static String? get accessToken => _accessToken;
  static String? get refreshToken => _refreshToken;
  static bool get hasAccessToken => _accessToken != null;
  static bool get hasRefreshToken =>
      _refreshToken != null && _refreshToken!.isNotEmpty;
  static bool get isRemembered => _remember;

  /// True when the access token is missing or within 30 s of expiring.
  static bool get accessTokenExpired {
    if (_accessToken == null) return true;
    final exp = _accessExpiry;
    if (exp == null) return false; // no readable exp: trust the token
    return DateTime.now()
        .toUtc()
        .isAfter(exp.subtract(const Duration(seconds: 30)));
  }

  /// Persists a signed-in session.
  ///
  /// A null [refreshToken] leaves the existing one untouched — profile
  /// completion returns no new refresh token, and rotating on it would log the
  /// user out. A null [remember] leaves the remember-me choice untouched.
  static Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    bool? remember,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _setAccessToken(accessToken);
    await prefs.setString(_accessKey, accessToken);

    if (remember != null) {
      _remember = remember;
      await prefs.setBool(_rememberKey, remember);
    }

    if (refreshToken != null) {
      _refreshToken = refreshToken;
      if (_remember) {
        await _writeSecure(refreshToken);
      } else {
        // "Remember me" off: keep the token in memory for this run only.
        await _deleteSecure();
      }
    } else if (!_remember) {
      await _deleteSecure();
    }
  }

  /// Drops the session entirely. The remembered identifier is deliberately kept
  /// so the login form can still greet the user by name.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = null;
    _accessExpiry = null;
    _refreshToken = null;
    await prefs.remove(_accessKey);
    await _deleteSecure();
  }

  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  static Future<String?> readRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<void> saveIdentifier(String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_identifierKey, identifier);
  }

  static Future<String?> readIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_identifierKey);
  }

  static Future<void> clearIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_identifierKey);
  }

  static Future<bool> readRemember() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberKey) ?? true;
  }

  static Future<void> _writeSecure(String value) async {
    try {
      await _secure.write(key: _refreshKey, value: value);
    } catch (_) {
      // Keystore unavailable: the token still works for this run (memory).
    }
  }

  static Future<void> _deleteSecure() async {
    try {
      await _secure.delete(key: _refreshKey);
    } catch (_) {}
  }

  @visibleForTesting
  static void debugReset() {
    _accessToken = null;
    _accessExpiry = null;
    _refreshToken = null;
    _remember = true;
  }
}
