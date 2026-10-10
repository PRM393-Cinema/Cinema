import '../models/auth_response.dart';
import '../models/paged_result.dart';
import '../models/login_request.dart';
import '../models/otp_sent_response.dart';
import '../models/register_request.dart';
import '../models/reset_password_request.dart';
import '../models/verify_email_request.dart';
import '../services/auth_service.dart';
import '../storage/auth_token_storage.dart';

abstract interface class AuthRepository {
  Future<PagedResult<AuthUser>> users({
    int page = 1,
    String? keyword,
    String? role,
    bool? enabled,
  });
  Future<AuthUser> getUser(int id);
  Future<List<String>> roles();
  Future<AuthUser> createUser({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required List<String> roles,
  });
  Future<AuthUser> updateUserRoles(int id, List<String> roles);
  Future<AuthUser> updateUserStatus(int id, bool enabled);
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

  Future<OtpSentResponse> forgotPassword({required String email});

  Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  });

  // The signed-in user saved on this device, or null when signed out.
  Future<AuthUser?> restoreSession();

  // Loads the signed-in user from the backend and updates the saved copy.
  Future<AuthUser> currentUser();

  Future<void> logout();
}

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required AuthService service,
    required AuthTokenStorage storage,
  }) : _authService = service,
       _tokenStorage = storage;

  final AuthService _authService;
  final AuthTokenStorage _tokenStorage;

  @override
  Future<PagedResult<AuthUser>> users({
    int page = 1,
    String? keyword,
    String? role,
    bool? enabled,
  }) => _authService.users(
    page: page,
    keyword: keyword,
    role: role,
    enabled: enabled,
  );
  @override
  Future<AuthUser> getUser(int id) => _authService.user(id);
  @override
  Future<List<String>> roles() => _authService.roles();
  @override
  Future<AuthUser> createUser({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required List<String> roles,
  }) => _authService.createUser(
    fullName: fullName,
    email: email,
    password: password,
    phone: phone,
    roles: roles,
  );
  @override
  Future<AuthUser> updateUserRoles(int id, List<String> roles) =>
      _authService.updateUserRoles(id, roles);
  @override
  Future<AuthUser> updateUserStatus(int id, bool enabled) =>
      _authService.updateUserStatus(id, enabled);

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

  @override
  Future<OtpSentResponse> forgotPassword({required String email}) {
    return _authService.forgotPassword(email);
  }

  @override
  Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _authService.resetPassword(
      ResetPasswordRequest(email: email, otp: otp, newPassword: newPassword),
    );
  }

  @override
  Future<AuthUser?> restoreSession() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    final user = await _tokenStorage.readUser();
    if (refreshToken == null || user == null) {
      await _tokenStorage.clear();
      return null;
    }

    // An expired access token is renewed on the first request that needs it.
    return user;
  }

  @override
  Future<AuthUser> currentUser() async {
    final user = await _authService.me();
    await _tokenStorage.saveUser(user);
    return user;
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefreshToken();

    try {
      if (refreshToken != null) {
        await _authService.logout(refreshToken);
      }
    } on Object {
      // Signing out on this device must work even if the server is offline.
    } finally {
      await _tokenStorage.clear();
    }
  }
}
