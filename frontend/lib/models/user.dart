class AppUser {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final bool phoneVerified;
  final String authProvider;
  final String? providerUserId;
  final String? profileImage;
  final bool profileComplete;
  final String? location;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.phoneVerified = false,
    this.authProvider = 'password',
    this.providerUserId,
    this.profileImage,
    this.profileComplete = true,
    this.location,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      phone: json['phone'],
      phoneVerified: json['phone_verified'] ?? false,
      authProvider: json['auth_provider'] ?? 'password',
      providerUserId: json['provider_user_id'],
      profileImage: json['profile_image'],
      profileComplete: json['profile_complete'] ?? true,
      location: json['location'],
    );
  }
}
