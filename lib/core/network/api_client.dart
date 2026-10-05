import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'access_token_provider.dart';
import 'api_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
    this.tokenProvider,
    this.timeout = const Duration(seconds: 15),
  }) : _httpClient = httpClient ?? http.Client(),
       baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _httpClient;
  final String baseUrl;
  final Duration timeout;
  final AccessTokenProvider? tokenProvider;

  Future<Object?> get(
    String path, {
    Map<String, Object?>? query,
    bool authenticated = false,
  }) {
    return _send('GET', path, query: query, authenticated: authenticated);
  }

  Future<Object?> post(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    bool authenticated = false,
  }) {
    return _send(
      'POST',
      path,
      body: body,
      query: query,
      authenticated: authenticated,
    );
  }

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
    required bool authenticated,
  }) async {
    final uri = _buildUri(path, query);
    final provider = tokenProvider;
    final token = authenticated ? await provider?.accessToken() : null;

    var response = await _request(method, uri, body, token);

    // The access token lives for an hour: renew it once with the refresh
    // token and repeat the request before reporting the session as expired.
    if (response.statusCode == 401 && provider != null && token != null) {
      final renewedToken = await provider.refreshAccessToken(
        failedToken: token,
      );
      if (renewedToken == null) {
        throw const ApiException(
          statusCode: 401,
          message: 'Your session has expired. Please sign in again.',
        );
      }

      response = await _request(method, uri, body, renewedToken);
    }

    if (authenticated && response.statusCode == 401) {
      throw const ApiException(
        statusCode: 401,
        message: 'Please sign in again to continue.',
      );
    }

    return _decodeResponse(response);
  }

  Uri _buildUri(String path, Map<String, Object?>? query) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: {
        for (final entry in query.entries)
          if (entry.value != null) entry.key: '${entry.value}',
      },
    );
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    Object? body,
    String? bearerToken,
  ) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (bearerToken != null && bearerToken.isNotEmpty)
        'Authorization': 'Bearer $bearerToken',
    };

    try {
      final future = switch (method) {
        'GET' => _httpClient.get(uri, headers: headers),
        'POST' => _httpClient.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        _ => throw UnsupportedError('Unsupported method $method'),
      };

      return await future.timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        message: 'The request timed out. Please try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Unable to connect to the server. Please try again.',
      );
    }
  }

  Object? _decodeResponse(http.Response response) {
    final body = response.body.trim();
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

    Object? decoded;
    try {
      decoded = body.isEmpty ? null : jsonDecode(body);
    } on FormatException {
      if (isSuccess) {
        throw const ApiException(
          message: 'The server returned an invalid response.',
        );
      }
      // Some errors come back as plain text, e.g. BadRequest("...").
      decoded = body.length <= 300 ? {'detail': body} : null;
    }

    if (isSuccess) {
      return decoded;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: _errorMessage(decoded, response.statusCode),
      details: decoded,
    );
  }

  String _errorMessage(Object? decoded, int statusCode) {
    if (decoded is Map) {
      final error = Map<String, Object?>.from(decoded);
      final detail = error['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }

      final errors = error['errors'];
      if (errors is Map) {
        final messages = errors.values
            .expand((value) => value is List ? value : const [])
            .whereType<String>()
            .where((message) => message.trim().isNotEmpty)
            .toList();
        if (messages.isNotEmpty) {
          return messages.join('\n');
        }
      }

      final title = error['title'];
      if (title is String && title.trim().isNotEmpty) {
        return title;
      }

      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    return switch (statusCode) {
      400 => 'Please check your information and try again.',
      401 => 'Invalid email or password.',
      403 => 'You do not have permission to continue.',
      404 => 'The requested data was not found.',
      409 => 'This action conflicts with the current data. Please refresh and try again.',
      429 => 'Too many requests. Please wait and try again.',
      >= 500 => 'The server is unavailable. Please try again later.',
      _ => 'Something went wrong. Please try again.',
    };
  }
}
