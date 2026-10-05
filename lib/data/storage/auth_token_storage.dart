import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_response.dart';

abstract interface class AuthTokenStorage {
  Future<void> save(AuthResponse response);
  Future<void> saveUser(AuthUser user);

  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<DateTime?> readExpiresAt();
  Future<AuthUser?> readUser();

  Future<void> clear();
}

class SecureAuthTokenStorage implements AuthTokenStorage {
  SecureAuthTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';
  static const _tokenTypeKey = 'auth.tokenType';
  static const _expiresAtKey = 'auth.expiresAt';
  static const _userKey = 'auth.user';

  final FlutterSecureStorage _storage;

  // Writes one value at a time: on web the first write creates the
  // encryption key, and parallel first writes would each create their own
  // key, leaving values that can no longer be decrypted.
  @override
  Future<void> save(AuthResponse response) async {
    await _storage.write(key: _accessTokenKey, value: response.accessToken);
    await _storage.write(key: _refreshTokenKey, value: response.refreshToken);
    await _storage.write(key: _tokenTypeKey, value: response.tokenType);
    await _storage.write(
      key: _expiresAtKey,
      value: response.expiresAt.toIso8601String(),
    );
    await saveUser(response.user);
  }

  @override
  Future<void> saveUser(AuthUser user) {
    return _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  @override
  Future<String?> readAccessToken() {
    return _read(_accessTokenKey);
  }

  @override
  Future<String?> readRefreshToken() {
    return _read(_refreshTokenKey);
  }

  @override
  Future<DateTime?> readExpiresAt() async {
    final str = await _read(_expiresAtKey);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  @override
  Future<AuthUser?> readUser() async {
    final str = await _read(_userKey);
    if (str == null) return null;

    try {
      return AuthUser.fromJson(Map<String, Object?>.from(jsonDecode(str)));
    } on Object {
      // Data saved by an older version of the app: treat as signed out.
      return null;
    }
  }

  @override
  Future<void> clear() async {
    for (final key in [
      _accessTokenKey,
      _refreshTokenKey,
      _tokenTypeKey,
      _expiresAtKey,
      _userKey,
    ]) {
      await _storage.delete(key: key);
    }
  }

  // A value that cannot be decrypted (e.g. saved by an older build) means
  // the session is lost: wipe it so the user can simply sign in again.
  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Object {
      await _storage.deleteAll();
      return null;
    }
  }
}
