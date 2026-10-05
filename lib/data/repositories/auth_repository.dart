import '../../core/network/api_client.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../models/otp_sent_response.dart';
import '../models/register_request.dart';
import '../models/verify_email_request.dart';
import '../services/auth_service.dart';
import '../storage/auth_token_storage.dart';

abstract interface class AuthRepository {
  Future<AuthResponse> login({required String email, required String password});

  Future<OtpSentResponse> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  });

  Future<AuthResponse> verifyEmail({
    required String email,
    required String otp,
    required String password,
  });

  Future<OtpSentResponse> resendVerification({required String email});
}

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required AuthService service,
    required AuthTokenStorage storage,
  }) : _authService = service,
       _tokenStorage = storage;

  factory RemoteAuthRepository.create() {
    return RemoteAuthRepository(
      service: AuthService(client: ApiClient()),
      storage: SecureAuthTokenStorage(),
    );
  }

  final AuthService _authService;
  final AuthTokenStorage _tokenStorage;

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _authService.login(
      LoginRequest(email: email, password: password),
    );
    await _tokenStorage.save(response);
    return response;
  }

  @override
  Future<OtpSentResponse> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) {
    return _authService.register(
      RegisterRequest(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
      ),
    );
  }

  @override
  Future<AuthResponse> verifyEmail({
    required String email,
    required String otp,
    required String password,
  }) {
    return _authService.verifyEmail(
      VerifyEmailRequest(email: email, otp: otp, password: password),
    );
  }

  @override
  Future<OtpSentResponse> resendVerification({required String email}) {
    return _authService.resendVerification(email);
  }
}
