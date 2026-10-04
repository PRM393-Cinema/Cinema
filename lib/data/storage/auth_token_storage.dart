import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_response.dart';

abstract interface class AuthTokenStorage {
  Future<void> save(AuthResponse response);

  Future<String?> readAccessToken();
  Future<DateTime?> readExpiresAt();

  Future<void> clear();
}

class SecureAuthTokenStorage implements AuthTokenStorage {
  SecureAuthTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';
  static const _tokenTypeKey = 'auth.tokenType';
  static const _expiresAtKey = 'auth.expiresAt';

  final FlutterSecureStorage _storage;

  @override
  Future<void> save(AuthResponse response) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: response.accessToken),
      _storage.write(key: _refreshTokenKey, value: response.refreshToken),
      _storage.write(key: _tokenTypeKey, value: response.tokenType),
      _storage.write(
        key: _expiresAtKey,
        value: response.expiresAt.toIso8601String(),
      ),
    ]);
  }

  @override
  Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  @override
  Future<DateTime?> readExpiresAt() async {
    final str = await _storage.read(key: _expiresAtKey);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _tokenTypeKey),
      _storage.delete(key: _expiresAtKey),
    ]);
  }
}
