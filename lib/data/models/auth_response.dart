class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresAt,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, Object?> json) {
    final userJson = Map<String, Object?>.from(json['user'] as Map);

    return AuthResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      user: AuthUser.fromJson(userJson),
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime expiresAt;
  final AuthUser user;
}

class AuthUser {
  const AuthUser({
    required this.userId,
    required this.email,
    required this.enabled,
    required this.emailVerified,
    required this.createdAt,
    required this.roles,
    this.fullName,
    this.phone,
  });

  factory AuthUser.fromJson(Map<String, Object?> json) {
    return AuthUser(
      userId: json['userId'] as int,
      email: json['email'] as String,
      fullName: json['fullName'] as String?,
      phone: json['phone'] as String?,
      enabled: json['enabled'] as bool,
      emailVerified: json['emailVerified'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      roles: (json['roles'] as List<dynamic>).whereType<String>().toList(),
    );
  }

  final int userId;
  final String email;
  final String? fullName;
  final String? phone;
  final bool enabled;
  final bool emailVerified;
  final DateTime createdAt;
  final List<String> roles;

  String get displayName {
    final name = fullName?.trim();
    return name == null || name.isEmpty ? email : name;
  }

  Map<String, Object?> toJson() {
    return {
      'userId': userId,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'enabled': enabled,
      'emailVerified': emailVerified,
      'createdAt': createdAt.toIso8601String(),
      'roles': roles,
    };
  }
}
