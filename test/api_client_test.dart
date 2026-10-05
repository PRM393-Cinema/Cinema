import 'dart:convert';

import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/network/api_exception.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/services/auth_service.dart';
import 'package:cinema_fe/data/storage/auth_token_storage.dart';
import 'package:cinema_fe/data/storage/token_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fixtures.dart';

void main() {
  late _MemoryTokenStorage storage;
  late List<http.Request> requests;
  late int refreshCalls;
  late bool refreshTokenRevoked;
  late List<AuthUser> renewedUsers;
  late int expiredCalls;

  // Backend stand-in: protected endpoints only accept 'fresh-token'.
  http.Response backend(http.Request request) {
    requests.add(request);
    final path = request.url.path;

    if (path == '/api/v1/auth/refresh') {
      refreshCalls++;
      if (refreshTokenRevoked) {
        return _json(401, {
          'status': 401,
          'title': 'Unauthorized',
          'detail': 'Refresh token đã bị thu hồi.',
        });
      }
      return _json(200, _authJson(accessToken: 'fresh-token'));
    }

    if (request.headers['Authorization'] != 'Bearer fresh-token') {
      return http.Response('', 401);
    }

    if (path == '/api/v1/bookings') {
      return _json(409, {
        'status': 409,
        'title': 'Conflict',
        'detail': 'Seat B1 is already held by another booking.',
      });
    }

    return _json(200, {'path': path, 'query': request.url.query});
  }

  ApiClient buildClient() {
    late final AuthService authService;
    final tokenManager = TokenManager(
      storage: storage,
      refreshSession: (refreshToken) => authService.refresh(refreshToken),
      onSessionRenewed: renewedUsers.add,
      onSessionExpired: () => expiredCalls++,
    );
    final client = ApiClient(
      httpClient: MockClient((request) async => backend(request)),
      baseUrl: 'http://api.test',
      tokenProvider: tokenManager,
    );
    authService = AuthService(client: client);
    return client;
  }

  setUp(() {
    storage = _MemoryTokenStorage()
      ..accessToken = 'expired-token'
      ..refreshToken = 'refresh-token';
    requests = [];
    refreshCalls = 0;
    refreshTokenRevoked = false;
    renewedUsers = [];
    expiredCalls = 0;
  });

  test(
    'Expired access token is renewed once and the request repeated',
    () async {
      final client = buildClient();

      final response = await client.get(
        '/api/v1/bookings/user/3',
        query: {'page': 1, 'size': 50, 'skipped': null},
        authenticated: true,
      );

      expect(response, {
        'path': '/api/v1/bookings/user/3',
        'query': 'page=1&size=50',
      });
      expect(refreshCalls, 1);
      expect(storage.accessToken, 'fresh-token');
      expect(storage.refreshToken, 'rotated-refresh-token');
      expect(renewedUsers.single.userId, customerUser.userId);
      expect(requests.map((r) => r.url.path), [
        '/api/v1/bookings/user/3',
        '/api/v1/auth/refresh',
        '/api/v1/bookings/user/3',
      ]);
    },
  );

  test('Concurrent 401s share a single refresh call', () async {
    final client = buildClient();

    await Future.wait([
      client.get('/api/v1/bookings/1', authenticated: true),
      client.get('/api/v1/bookings/2', authenticated: true),
      client.get('/api/v1/notifications/user/3', authenticated: true),
    ]);

    // The backend revokes a refresh token once used, so a second refresh
    // with the same token would sign the user out.
    expect(refreshCalls, 1);
  });

  test('Revoked refresh token signs the user out', () async {
    refreshTokenRevoked = true;
    final client = buildClient();

    await expectLater(
      client.get('/api/v1/auth/me', authenticated: true),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having(
              (e) => e.message,
              'message',
              contains('session has expired'),
            ),
      ),
    );
    expect(expiredCalls, 1);
    expect(storage.accessToken, isNull);
    expect(storage.refreshToken, isNull);
  });

  test('Public requests are sent without a token', () async {
    final client = buildClient();

    await expectLater(
      client.get('/api/v1/movies/status/ACTIVE'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
    expect(requests.single.headers.containsKey('Authorization'), isFalse);
    expect(refreshCalls, 0);
  });

  test('ProblemDetails detail becomes the error message', () async {
    storage.accessToken = 'fresh-token';
    final client = buildClient();

    await expectLater(
      client.post(
        '/api/v1/bookings',
        body: {'showtimeId': 11},
        authenticated: true,
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having(
              (e) => e.message,
              'message',
              'Seat B1 is already held by another booking.',
            ),
      ),
    );
    expect(
      requests.single.headers['Content-Type'],
      startsWith('application/json'),
    );
    expect(jsonDecode(requests.single.body), {'showtimeId': 11});
  });

  test('Plain text error bodies are kept as the message', () async {
    final client = ApiClient(
      httpClient: MockClient(
        (_) async => http.Response('Payment method is required.', 400),
      ),
      baseUrl: 'http://api.test',
    );

    await expectLater(
      client.post('/api/v1/bookings/1/confirm'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Payment method is required.',
        ),
      ),
    );
  });

  test('Connection failures become a friendly error', () async {
    final client = ApiClient(
      httpClient: MockClient(
        (_) async => throw http.ClientException('Connection refused'),
      ),
      baseUrl: 'http://api.test',
    );

    await expectLater(
      client.get('/api/v1/movies'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Unable to connect to the server. Please try again.',
        ),
      ),
    );
  });
}

http.Response _json(int status, Object body) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, Object?> _authJson({required String accessToken}) {
  return {
    'accessToken': accessToken,
    'refreshToken': 'rotated-refresh-token',
    'tokenType': 'Bearer',
    'expiresAt': '2026-10-05T21:00:00',
    'user': customerUser.toJson(),
  };
}

class _MemoryTokenStorage implements AuthTokenStorage {
  String? accessToken;
  String? refreshToken;
  AuthUser? user;

  @override
  Future<void> save(AuthResponse response) async {
    accessToken = response.accessToken;
    refreshToken = response.refreshToken;
    user = response.user;
  }

  @override
  Future<void> saveUser(AuthUser user) async {
    this.user = user;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<DateTime?> readExpiresAt() async => null;

  @override
  Future<AuthUser?> readUser() async => user;

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    user = null;
  }
}
