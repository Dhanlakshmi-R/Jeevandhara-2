import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jeevandhara2/models/auth_result.dart';
import 'package:jeevandhara2/models/session_info.dart';
import 'package:jeevandhara2/models/user.dart';
import 'package:jeevandhara2/services/session_store.dart';

class ApiException implements Exception {
  final String message;

  /// The HTTP status, when the failure came from the server. Callers use 401 to
  /// mean "the session is gone", distinct from a network failure.
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Outcome of a silent session restore on app start.
class SessionRestore {
  /// Whether a persisted session exists. True even when [user] is null because
  /// the refresh could not reach the server — the session should be kept, not
  /// discarded, so the app does not log a user out for being briefly offline.
  final bool hasSession;
  final AppUser? user;

  const SessionRestore({required this.hasSession, this.user});
}

class ApiService {
  // Android emulator reaches the host machine's localhost via 10.0.2.2.
  // - iOS simulator: use 'http://localhost:8000'
  // - Physical device: use your computer's LAN IP, e.g. 'http://192.168.1.5:8000'
  static const String baseUrl = 'http://localhost:8000';

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Used by the static [readToken] path, which has no instance to borrow a
  /// client from. Kept separate so the shared refresh never races an injected
  /// test client.
  static final http.Client _sharedClient = http.Client();

  /// De-duplicates concurrent silent refreshes: many services call
  /// [readToken] at once on cold start, and each must not rotate the token.
  static Future<AuthResult>? _refreshInFlight;

  /// Reads the stored access token so other services (listings, market) can
  /// attach `Authorization: Bearer`. Silently refreshes a stale token first, so
  /// a request made after the short-lived access token expired still succeeds.
  static Future<String?> readToken() async {
    await _ensureFreshAccessToken();
    return SessionStore.accessToken;
  }

  static Future<void> _ensureFreshAccessToken() async {
    if (!SessionStore.accessTokenExpired) return;
    if (!SessionStore.hasRefreshToken) return;
    final inFlight = _refreshInFlight ??= _refreshWith(_sharedClient);
    try {
      await inFlight;
    } catch (_) {
      // Leave the stale token in place; the caller's own 401 handling decides.
    } finally {
      if (identical(_refreshInFlight, inFlight)) _refreshInFlight = null;
    }
  }

  /// Exchanges the refresh token for a new access + refresh token (rotation).
  ///
  /// On a 401 the session is cleared locally: the backend revokes the session
  /// when a refresh token is replayed, so there is nothing left to salvage.
  static Future<AuthResult> _refreshWith(
    http.Client client, {
    bool? remember,
  }) async {
    final refresh = SessionStore.refreshToken;
    if (refresh == null) {
      throw ApiException('Not logged in', statusCode: 401);
    }
    final response = await client.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refresh}),
    );
    if (response.statusCode != 200) {
      if (response.statusCode == 401) {
        await SessionStore.clear();
      }
      throw ApiException(
        _extractError(response),
        statusCode: response.statusCode,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final result = AuthResult.fromJson(data);
    await SessionStore.saveSession(
      accessToken: result.token,
      refreshToken: result.refreshToken,
      remember: remember,
    );
    await SessionStore.saveRole(result.user.role);
    return result;
  }

  /// Rotates the session on demand (the same exchange the silent path uses).
  Future<AuthResult> refreshSession() => _refreshWith(_client);

  /// Restores a persisted session on app start, returning the fresh user.
  Future<SessionRestore> restoreSession() async {
    if (!SessionStore.hasRefreshToken) {
      return const SessionRestore(hasSession: false);
    }
    try {
      final result = await _refreshWith(_client);
      return SessionRestore(hasSession: true, user: result.user);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // Token rejected (expired, revoked, or replayed): truly signed out.
        return const SessionRestore(hasSession: false);
      }
      // Network or server error: keep the session and retry later.
      return const SessionRestore(hasSession: true);
    } catch (_) {
      return const SessionRestore(hasSession: true);
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role, // 'farmer' or 'trader'
    String? phone,
    String? location,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'phone': phone,
        'location': location,
      }),
    );

    if (response.statusCode != 201) {
      throw ApiException(_extractError(response),
          statusCode: response.statusCode);
    }
  }

  /// Signs in with email and password.
  ///
  /// [rememberMe] decides whether the refresh token is written to the OS
  /// keystore. When false the session lasts only until the app is closed. The
  /// password itself is never stored.
  Future<AuthResult> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    // Login uses OAuth2's form-encoded convention (username/password fields),
    // matching FastAPI's OAuth2PasswordRequestForm on the backend.
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response),
          statusCode: response.statusCode);
    }
    return _consumeAuthResult(response, remember: rememberMe);
  }

  Future<AuthResult> googleLogin(String idToken) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response),
          statusCode: response.statusCode);
    }
    return _consumeAuthResult(response);
  }

  Future<int> sendOtp(String phone) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/otp/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response),
          statusCode: response.statusCode);
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['resend_after_seconds'] as num?)?.toInt() ?? 30;
  }

  Future<AuthResult> verifyOtp(String phone, String otp) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'otp': otp}),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response),
          statusCode: response.statusCode);
    }
    return _consumeAuthResult(response);
  }

  Future<AuthResult> completeProfile({
    required String name,
    required String role,
    String? phone,
    String? location,
    String? profileImage,
  }) async {
    final token = await readToken();
    if (token == null) {
      throw ApiException('Not logged in', statusCode: 401);
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/auth/complete-profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'role': role,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (location != null && location.isNotEmpty) 'location': location,
        if (profileImage != null && profileImage.isNotEmpty)
          'profile_image': profileImage,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response),
          statusCode: response.statusCode);
    }
    // Profile completion reuses the current session, so the response carries no
    // new refresh token; [remember] stays null and the existing one is kept.
    return _consumeAuthResult(response);
  }

  Future<AuthResult> _consumeAuthResult(
    http.Response response, {
    bool? remember,
  }) async {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final result = AuthResult.fromJson(data);
    await SessionStore.saveSession(
      accessToken: result.token,
      refreshToken: result.refreshToken,
      remember: remember,
    );
    await SessionStore.saveRole(result.user.role);
    return result;
  }

  Future<void> saveUserRole(String role) => SessionStore.saveRole(role);

  Future<String?> getSavedRole() => SessionStore.readRole();

  Future<AppUser> getCurrentUser() async {
    final token = await readToken();
    if (token == null) {
      throw ApiException('Not logged in', statusCode: 401);
    }

    var response = await _client.get(
      Uri.parse('$baseUrl/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    // A token that verifies but was revoked server-side (e.g. signed out from
    // another device) gets one silent rotation, then the request is retried.
    if (response.statusCode == 401 && SessionStore.hasRefreshToken) {
      final refreshed = await _refreshWith(_client);
      response = await _client.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {'Authorization': 'Bearer ${refreshed.token}'},
      );
    }

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response),
          statusCode: response.statusCode);
    }

    return AppUser.fromJson(jsonDecode(response.body));
  }

  Future<bool> isLoggedIn() async =>
      SessionStore.hasRefreshToken || SessionStore.hasAccessToken;

  /// Closes this device's session on the server, then drops it locally.
  ///
  /// The server call is best-effort: a network failure must not trap the user
  /// inside the app, so the local session is always cleared.
  Future<void> logout() async {
    final token = SessionStore.accessToken;
    if (token != null) {
      try {
        await _client.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } catch (_) {
        // Ignored: signing out locally is what matters to the user.
      }
    }
    await SessionStore.clear();
  }

  /// The list of devices this account is signed in on.
  Future<List<SessionInfo>> listSessions() async {
    final token = await readToken();
    if (token == null) {
      throw ApiException('Not logged in', statusCode: 401);
    }
    final response = await _client.get(
      Uri.parse('$baseUrl/auth/sessions'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw ApiException(_extractError(response),
          statusCode: response.statusCode);
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => SessionInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Signs out one of this account's other devices.
  Future<void> revokeSession(int sessionId) async {
    final token = await readToken();
    if (token == null) {
      throw ApiException('Not logged in', statusCode: 401);
    }
    final response = await _client.delete(
      Uri.parse('$baseUrl/auth/sessions/$sessionId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw ApiException(_extractError(response),
          statusCode: response.statusCode);
    }
  }

  /// Signs out of every device, including this one.
  Future<void> logoutAll() async {
    final token = SessionStore.accessToken;
    if (token != null) {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/logout-all'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw ApiException(_extractError(response),
            statusCode: response.statusCode);
      }
    }
    await SessionStore.clear();
  }

  static String _extractError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      final detail = data['detail'];
      if (detail is String) {
        return convertApiMessage(detail);
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        final msg = first['msg']?.toString();
        if (msg != null) return msg;
      }
      return 'Something went wrong';
    } catch (_) {
      return 'Something went wrong (${response.statusCode})';
    }
  }
}

/// Maps common FastAPI detail strings to friendlier, shorter messages.
String convertApiMessage(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('enter a valid indian mobile number')) {
    return 'Enter a valid 10-digit mobile number';
  }
  if (lower.contains('code expired')) {
    return 'Code expired. Request a new one.';
  }
  if (lower.contains('too many incorrect attempts')) {
    return 'Too many wrong attempts. Request a new code.';
  }
  if (lower.contains('incorrect code')) {
    return 'Incorrect code. Please try again.';
  }
  if (lower.contains('sms provider is not configured')) {
    return 'OTP is not available right now. Try Google or email login.';
  }
  if (lower.contains('google sign-in is not configured')) {
    return 'Google login is not set up yet. Use email instead.';
  }
  if (lower.contains('too many requests')) {
    return 'Too many requests. Please wait a moment and retry.';
  }
  return message;
}
