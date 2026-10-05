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
  final void Function()? onSessionExpired;

  Future<String?>? _pendingRefresh;

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
    // Another request may already have renewed the token.
    final current = await _tokenStorage.readAccessToken();
    if (current != null && current != failedToken) {
      return current;
    }

    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _expire();
      return null;
    }

    try {
      final response = await _refreshTokens(refreshToken);
      await _tokenStorage.save(response);
      onSessionRenewed?.call(response.user);
      return response.accessToken;
    } on ApiException catch (error) {
      // 400/401: the refresh token is invalid, revoked or expired. Network
      // errors keep the session so the user can retry.
      if (error.statusCode == 400 || error.statusCode == 401) {
        await _expire();
        return null;
      }
      rethrow;
    }
  }

  Future<void> _expire() async {
    await _tokenStorage.clear();
    onSessionExpired?.call();
  }
}
