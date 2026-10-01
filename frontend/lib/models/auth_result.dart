import 'user.dart';

class AuthResult {
  final String token;
  final bool profileComplete;
  final AppUser user;

  AuthResult({
    required this.token,
    required this.profileComplete,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['access_token'] as String,
      profileComplete: json['profile_complete'] as bool,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
