import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    this.baseUrl = ApiConfig.baseUrl,
    this.timeout = const Duration(seconds: 15),
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final String baseUrl;
  final Duration timeout;

  Future<Object?> get(String path, {String? bearerToken}) {
    return _send('GET', path, bearerToken: bearerToken);
  }

  Future<Object?> post(String path, {Object? body, String? bearerToken}) {
    return _send('POST', path, body: body, bearerToken: bearerToken);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    String? bearerToken,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
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

      final response = await future.timeout(timeout);

      return _decodeResponse(response);
    } on TimeoutException {
      throw const ApiException(
        message: 'The request timed out. Please try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Unable to connect to the server. Please try again.',
      );
    } on FormatException {
      throw const ApiException(
        message: 'The server returned an invalid response.',
      );
    }
  }

  Object? _decodeResponse(http.Response response) {
    final body = response.body.trim();
    final decoded = body.isEmpty ? null : jsonDecode(body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
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
      429 => 'Too many requests. Please wait and try again.',
      >= 500 => 'The server is unavailable. Please try again later.',
      _ => 'Something went wrong. Please try again.',
    };
  }
}
