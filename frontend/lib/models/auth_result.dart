import 'user.dart';

class AuthResult {
  final String token;

  /// Long-lived token used only to mint fresh access tokens. Null when the
  /// response reused an existing session (profile completion) rather than
  /// opening a new one.
  final String? refreshToken;
  final bool profileComplete;
  final AppUser user;

  AuthResult({
    required this.token,
    this.refreshToken,
    required this.profileComplete,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      profileComplete: json['profile_complete'] as bool,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
