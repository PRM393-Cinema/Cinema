import '../../core/network/api_client.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';

class AuthService {
  AuthService({required ApiClient client}) : _apiClient = client;

  final ApiClient _apiClient;

  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _apiClient.post(
      '/api/v1/auth/login',
      body: request.toJson(),
    );

    if (response is! Map) {
      throw const FormatException('Expected auth response object.');
    }

    return AuthResponse.fromJson(Map<String, Object?>.from(response));
  }
}
