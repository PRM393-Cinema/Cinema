import '../../core/network/access_token_provider.dart';
import '../../core/network/api_exception.dart';
import '../models/auth_response.dart';
import 'auth_token_storage.dart';

typedef RefreshSession = Future<AuthResponse> Function(String refreshToken);

// Hands out the stored access token and renews it with the refresh token.
// The backend rotates refresh tokens (the old one is revoked), so concurrent
// 401s must share a single refresh call.
class TokenManager implements AccessTokenProvider {
  TokenManager({
    required AuthTokenStorage storage,
    required RefreshSession refreshSession,
    this.onSessionRenewed,
    this.onSessionExpired,
  }) : _tokenStorage = storage,
       _refreshTokens = refreshSession;

  final AuthTokenStorage _tokenStorage;
  final RefreshSession _refreshTokens;
  final void Function(AuthUser user)? onSessionRenewed;
  final void Function(String message)? onSessionExpired;

  Future<String?>? _pendingRefresh;
  Future<void>? _pendingExpiry;
  int _sessionVersion = 0;

  @override
  Future<String?> accessToken() {
    return _tokenStorage.readAccessToken();
  }

  @override
  Future<String?> refreshAccessToken({required String failedToken}) {
    return _pendingRefresh ??= _refresh(failedToken).whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<String?> _refresh(String failedToken) async {
    final sessionVersion = _sessionVersion;
    // Another request may already have renewed the token.
    final current = await _tokenStorage.readAccessToken();
    if (current != null && current != failedToken) {
      return current;
    }

    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await expireSession(
        message: 'Your session has expired. Please sign in again.',
      );
      return null;
    }

    try {
      final response = await _refreshTokens(refreshToken);
      // A lock response must win over a refresh already in flight.
      if (sessionVersion != _sessionVersion) return null;
      await _tokenStorage.save(response);
      if (sessionVersion != _sessionVersion) {
        await _tokenStorage.clear();
        return null;
      }
      onSessionRenewed?.call(response.user);
      return response.accessToken;
    } on ApiException catch (error) {
      if (error.requiresSignInAgain) {
        await expireSession(message: error.message);
        return null;
      }
      // 400/401: the refresh token is invalid, revoked or expired. Network
      // errors keep the session so the user can retry.
      if (error.statusCode == 400 || error.statusCode == 401) {
        await expireSession(
          message: 'Your session has expired. Please sign in again.',
        );
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> expireSession({required String message}) {
    _sessionVersion++;
    return _pendingExpiry ??= _clearSession(message).whenComplete(() {
      _pendingExpiry = null;
    });
  }

  Future<void> _clearSession(String message) async {
    try {
      await _tokenStorage.clear();
    } finally {
      onSessionExpired?.call(message);
    }
  }
}
