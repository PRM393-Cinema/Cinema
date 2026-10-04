import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/login_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LoginRequest serializes backend fields', () {
    const request = LoginRequest(email: 'admin@cinema.com', password: '123456');

    expect(request.toJson(), {
      'email': 'admin@cinema.com',
      'password': '123456',
    });
  });

  test('AuthResponse maps backend fields', () {
    final response = AuthResponse.fromJson({
      'accessToken': 'access-token',
      'refreshToken': 'refresh-token',
      'tokenType': 'Bearer',
      'expiresAt': '2026-10-04T12:00:00',
      'user': {
        'userId': 1,
        'email': 'admin@cinema.com',
        'fullName': 'Admin',
        'phone': null,
        'enabled': true,
        'emailVerified': true,
        'createdAt': '2026-10-01T08:30:00',
        'roles': ['ROLE_ADMIN'],
      },
    });

    expect(response.accessToken, 'access-token');
    expect(response.refreshToken, 'refresh-token');
    expect(response.user.email, 'admin@cinema.com');
    expect(response.user.roles, ['ROLE_ADMIN']);
  });
}
