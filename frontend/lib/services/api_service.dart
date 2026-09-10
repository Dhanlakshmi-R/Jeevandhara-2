import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

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
  static const String baseUrl = 'http://10.0.2.2:8000';

  static const _tokenKey = 'auth_token';

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

  Future<void> login({required String email, required String password}) async {
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

    final data = jsonDecode(response.body);
    final token = data['access_token'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
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
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  String _extractError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['detail']?.toString() ?? 'Something went wrong';
    } catch (_) {
      return 'Something went wrong (${response.statusCode})';
    }
  }
}
