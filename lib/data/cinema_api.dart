import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:5000',
);

class CinemaApi {
  CinemaApi() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _user;

  bool get isSignedIn => _accessToken != null;
  Map<String, dynamic>? get user => _user;

  Future<void> restoreSession() async {
    _accessToken = await _storage.read(key: 'access_token');
    _refreshToken = await _storage.read(key: 'refresh_token');
    final savedUser = await _storage.read(key: 'user');
    if (savedUser != null) _user = _asMap(jsonDecode(savedUser));
  }

  Future<void> signOut() async {
    try {
      if (_refreshToken != null) {
        await _request(
          '/api/v1/auth/logout',
          method: 'POST',
          body: {'refreshToken': _refreshToken},
        );
      }
    } finally {
      _accessToken = null;
      _refreshToken = null;
      _user = null;
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
      await _storage.delete(key: 'user');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = _asMap(
      await _request(
        '/api/v1/auth/login',
        method: 'POST',
        body: {'email': email, 'password': password},
      ),
    );
    await _saveTokens(result);
    return _user!;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final result = _asMap(
      await _request(
        '/api/v1/auth/register',
        method: 'POST',
        body: {
          'email': email,
          'password': password,
          'fullName': fullName,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      ),
    );
    await _saveTokens(result);
    return _user!;
  }

  Future<void> _saveTokens(Map<String, dynamic> result) async {
    _accessToken = result['accessToken'] as String?;
    _refreshToken = result['refreshToken'] as String?;
    _user = _asMap(result['user']);
    if (_accessToken == null || _refreshToken == null) {
      throw const ApiException('Phản hồi đăng nhập không có token.');
    }
    await _storage.write(key: 'access_token', value: _accessToken);
    await _storage.write(key: 'refresh_token', value: _refreshToken);
    await _storage.write(key: 'user', value: jsonEncode(_user));
  }

  Future<Map<String, dynamic>> currentUser() async {
    _user = _asMap(await _request('/api/v1/auth/me'));
    await _storage.write(key: 'user', value: jsonEncode(_user));
    return _user!;
  }

  Future<List<Movie>> movies({String? keyword}) async {
    final path = keyword == null || keyword.trim().isEmpty
        ? '/api/v1/movies?page=1&size=50&sortBy=createdAt&sortDir=desc'
        : '/api/v1/movies/search?keyword=${Uri.encodeQueryComponent(keyword.trim())}&page=1&size=50';
    final result = _asMap(await _request(path));
    return _asList(result['items']).map(Movie.fromJson).toList();
  }

  Future<List<Showtime>> showtimesFor(int movieId) async {
    final result = _asMap(
      await _request(
        '/api/showtimes/movie/$movieId?pageNumber=1&pageSize=50&sortBy=startTime&sortDir=asc',
      ),
    );
    return _asList(result['items']).map(Showtime.fromJson).toList();
  }

  Future<List<Seat>> seatsForRoom(int roomId) async =>
      _asList(await _request('/api/seats/room/$roomId'))
          .map(Seat.fromJson)
          .toList();

  Future<List<int>> occupiedSeats(int showtimeId) async => _asList(
    await _request('/api/v1/bookings/showtime/$showtimeId/occupied-seats'),
  ).map((value) => (value as num).toInt()).toList();

  Future<Booking> createBooking({
    required int userId,
    required int showtimeId,
    required String movieTitle,
    required DateTime startTime,
    required List<int> seatIds,
  }) async => Booking.fromJson(
    _asMap(
      await _request(
        '/api/v1/bookings',
        method: 'POST',
        body: {
          'userId': userId,
          'showtimeId': showtimeId,
          'movieTitle': movieTitle,
          'showTime': startTime.toIso8601String(),
          'seats': seatIds.map((id) => {'seatId': id}).toList(),
        },
      ),
    ),
  );

  Future<List<Booking>> bookingsFor(int userId) async {
    final result = _asMap(
      await _request(
        '/api/v1/bookings/user/$userId?page=1&size=50&sortBy=createdAt&sortDir=desc',
      ),
    );
    return _asList(result['items']).map(Booking.fromJson).toList();
  }

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Object? body,
    bool retryAuth = true,
  }) async {
    final uri = Uri.parse(apiBaseUrl).resolve(path);
    final request = await _client
        .openUrl(method, uri)
        .timeout(const Duration(seconds: 15));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) request.headers.contentType = ContentType.json;
    if (_accessToken != null) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $_accessToken',
      );
    }
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close().timeout(const Duration(seconds: 15));
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == HttpStatus.unauthorized &&
        retryAuth &&
        _refreshToken != null &&
        !path.endsWith('/refresh')) {
      final refresh = _refreshToken;
      _accessToken = null;
      final renewed = _asMap(
        await _request(
          '/api/v1/auth/refresh',
          method: 'POST',
          body: {'refreshToken': refresh},
          retryAuth: false,
        ),
      );
      await _saveTokens(renewed);
      return _request(path, method: method, body: body, retryAuth: false);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(text, response.statusCode));
    }
    if (text.isEmpty) return null;
    return jsonDecode(text);
  }

  static String _errorMessage(String body, int status) {
    try {
      final value = _asMap(jsonDecode(body));
      final message = value['detail'] ?? value['title'] ?? value['message'];
      if (message is String && message.isNotEmpty) return message;
      final errors = value['errors'];
      if (errors is Map && errors.isNotEmpty)
        return errors.values.first.toString();
    } catch (_) {}
    return switch (status) {
      401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      403 => 'Bạn không có quyền thực hiện thao tác này.',
      404 => 'Không tìm thấy dữ liệu.',
      409 => 'Ghế vừa được người khác giữ. Hãy chọn ghế khác.',
      _ => 'Không thể hoàn tất yêu cầu ($status). Vui lòng thử lại.',
    };
  }
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Movie {
  const Movie({
    required this.id,
    required this.title,
    this.description = '',
    this.genre = '',
    this.duration = 0,
    this.posterUrl = '',
    this.status = '',
  });
  final int id;
  final String title, description, genre, posterUrl, status;
  final int duration;
  factory Movie.fromJson(Map<String, dynamic> json) => Movie(
    id: (json['id'] as num).toInt(),
    title: json['title']?.toString() ?? 'Phim chưa đặt tên',
    description: json['description']?.toString() ?? '',
    genre: json['genre']?.toString() ?? '',
    duration: (json['durationMinutes'] as num?)?.toInt() ?? 0,
    posterUrl: json['posterUrl']?.toString() ?? '',
    status: json['status']?.toString() ?? '',
  );
}

class Showtime {
  const Showtime({
    required this.id,
    required this.movieId,
    required this.roomId,
    required this.start,
    required this.end,
    required this.price,
  });
  final int id, movieId, roomId;
  final DateTime start, end;
  final double price;
  factory Showtime.fromJson(Map<String, dynamic> json) => Showtime(
    id: (json['id'] as num).toInt(),
    movieId: (json['movieId'] as num).toInt(),
    roomId: (json['roomId'] as num).toInt(),
    start: DateTime.parse(json['startTime'].toString()).toLocal(),
    end: DateTime.parse(json['endTime'].toString()).toLocal(),
    price: (json['price'] as num).toDouble(),
  );
}

class Seat {
  const Seat({
    required this.id,
    required this.row,
    required this.number,
    required this.type,
  });
  final int id, number;
  final String row, type;
  String get label => '$row$number';
  factory Seat.fromJson(Map<String, dynamic> json) => Seat(
    id: (json['id'] as num).toInt(),
    row: json['seatRow'].toString(),
    number: (json['seatNumber'] as num).toInt(),
    type: json['seatType']?.toString() ?? 'NORMAL',
  );
}

class Booking {
  const Booking({
    required this.id,
    required this.code,
    required this.movieTitle,
    required this.status,
    required this.amount,
    this.showTime,
    this.expiresAt,
    this.seats = const [],
  });
  final int id;
  final String code, movieTitle, status;
  final double amount;
  final DateTime? showTime, expiresAt;
  final List<String> seats;
  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
    id: (json['id'] as num).toInt(),
    code: json['bookingCode']?.toString() ?? '',
    movieTitle: json['movieTitle']?.toString() ?? 'Vé xem phim',
    status: json['status']?.toString() ?? 'PENDING',
    amount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
    showTime: DateTime.tryParse(json['showTime']?.toString() ?? '')?.toLocal(),
    expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '')
        ?.toLocal(),
    seats: _asList(json['seats'])
        .map((seat) => _asMap(seat)['seatLabel'].toString())
        .toList(),
  );
}

Map<String, dynamic> _asMap(dynamic value) =>
    Map<String, dynamic>.from(value as Map);
List<dynamic> _asList(dynamic value) => value is List ? value : const [];
