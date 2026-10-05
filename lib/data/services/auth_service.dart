import '../../core/network/api_client.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../models/otp_sent_response.dart';
import '../models/register_request.dart';
import '../models/verify_email_request.dart';

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

  Future<OtpSentResponse> register(RegisterRequest request) async {
    final response = await _apiClient.post(
      '/api/v1/auth/register',
      body: request.toJson(),
    );

    if (response is! Map) {
      throw const FormatException('Expected OTP response object.');
    }

    return OtpSentResponse.fromJson(Map<String, Object?>.from(response));
  }

  Future<AuthResponse> verifyEmail(VerifyEmailRequest request) async {
    final response = await _apiClient.post(
      '/api/v1/auth/verify-email',
      body: request.toJson(),
    );

    if (response is! Map) {
      throw const FormatException('Expected auth response object.');
    }

    return AuthResponse.fromJson(Map<String, Object?>.from(response));
  }

  Future<OtpSentResponse> resendVerification(String email) async {
    final response = await _apiClient.post(
      '/api/v1/auth/resend-verification',
      body: {'email': email},
    );

    if (response is! Map) {
      throw const FormatException('Expected OTP response object.');
    }

    return OtpSentResponse.fromJson(Map<String, Object?>.from(response));
  }
}
