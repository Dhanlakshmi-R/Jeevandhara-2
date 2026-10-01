import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jeevandhara2/models/auth_result.dart';
import 'package:jeevandhara2/models/user.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  // Android emulator reaches the host machine's localhost via 10.0.2.2.
  // - iOS simulator: use 'http://localhost:8000'
  // - Physical device: use your computer's LAN IP, e.g. 'http://192.168.1.5:8000'
  static const String baseUrl = 'http://localhost:8000';

  static const _tokenKey = 'auth_token';
  static const _roleKey = 'user_role';

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role, // 'farmer' or 'trader'
    String? phone,
    String? location,
  }) async {
    final response = await http.post(
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
      throw ApiException(_extractError(response));
    }
  }

  Future<AuthResult> login(
      {required String email, required String password}) async {
    // Login uses OAuth2's form-encoded convention (username/password fields),
    // matching FastAPI's OAuth2PasswordRequestForm on the backend.
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response));
    }

    final token = (jsonDecode(response.body)['access_token'] as String);
    await _saveToken(token);
    final user = await getCurrentUser();
    await saveUserRole(user.role);
    return AuthResult(
      token: token,
      profileComplete: user.profileComplete,
      user: user,
    );
  }

  Future<AuthResult> googleLogin(String idToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response));
    }
    return _consumeAuthResult(response);
  }

  Future<int> sendOtp(String phone) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/otp/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['resend_after_seconds'] as num?)?.toInt() ?? 30;
  }

  Future<AuthResult> verifyOtp(String phone, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'otp': otp}),
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response));
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
    final token = await _getToken();
    if (token == null) {
      throw ApiException('Not logged in');
    }

    final response = await http.post(
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
      throw ApiException(_extractError(response));
    }
    return _consumeAuthResult(response);
  }

  Future<AuthResult> _consumeAuthResult(http.Response response) async {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final result = AuthResult.fromJson(data);
    // Persist the session so splash/restores recognize it on next launch.
    await _saveToken(result.token);
    await saveUserRole(result.user.role);
    return result;
  }

  Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  Future<AppUser> getCurrentUser() async {
    final token = await _getToken();
    if (token == null) {
      throw ApiException('Not logged in');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw ApiException(_extractError(response));
    }

    return AppUser.fromJson(jsonDecode(response.body));
  }

  Future<bool> isLoggedIn() async {
    final token = await _getToken();
    return token != null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  String _extractError(http.Response response) {
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
