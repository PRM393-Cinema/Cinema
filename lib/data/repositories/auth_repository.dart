import '../../core/network/api_client.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../services/auth_service.dart';
import '../storage/auth_token_storage.dart';

abstract interface class AuthRepository {
  Future<AuthResponse> login({
    required String email,
    required String password,
  });
}

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required AuthService service,
    required AuthTokenStorage storage,
  })  : _authService = service,
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
}
