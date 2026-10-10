import '../../core/network/api_client.dart';
import '../models/app_notification.dart';
import '../models/booking.dart';
import '../models/json_readers.dart';
import '../models/movie.dart';
import '../models/paged_result.dart';
import '../models/payment.dart';
import '../models/room.dart';
import '../models/seat.dart';
import '../models/showtime.dart';

class StaffService {
  StaffService({required this._client});
  final ApiClient _client;

  Future<PagedResult<Booking>> bookings({
    int page = 1,
    String? status,
    int? userId,
    DateTime? start,
    DateTime? end,
  }) async => PagedResult.fromJson(
    await _client.get(
      userId != null
          ? '/api/v1/bookings/user/$userId'
          : status != null
          ? '/api/v1/bookings/status/$status'
          : start != null
          ? '/api/v1/bookings/date-range'
          : '/api/v1/bookings',
      authenticated: true,
      query: {
        'page': page,
        'size': 10,
        'sortBy': 'createdAt',
        'sortDir': 'desc',
        if (start != null) 'start': start.toIso8601String(),
        if (end != null) 'end': end.toIso8601String(),
      },
    ),
    Booking.fromJson,
  );
  Future<Booking> booking(int id) async => Booking.fromJson(
    readMap(await _client.get('/api/v1/bookings/$id', authenticated: true)),
  );
  Future<Booking> createBooking({
    required int userId,
    required String email,
    required int showtimeId,
    required List<int> seats,
  }) async => Booking.fromJson(
    readMap(
      await _client.post(
        '/api/v1/bookings',
        authenticated: true,
        body: {
          'userId': userId,
          'customerEmail': email,
          'showtimeId': showtimeId,
          'seats': [
            for (final id in seats) {'seatId': id},
          ],
        },
      ),
    ),
  );
  Future<Booking> confirmBooking(int id) async => Booking.fromJson(
    readMap(
      await _client.post(
        '/api/v1/bookings/$id/confirm',
        authenticated: true,
        query: {'paymentMethod': 'CASH'},
      ),
    ),
  );
  Future<Booking> cancelBooking(int id, String reason) async =>
      Booking.fromJson(
        readMap(
          await _client.post(
            '/api/v1/bookings/$id/cancel',
            authenticated: true,
            query: {'reason': reason},
          ),
        ),
      );

  Future<PagedResult<PaymentInfo>> payments({
    int page = 1,
    int? bookingId,
  }) async => PagedResult.fromJson(
    await _client.get(
      bookingId == null
          ? '/api/v1/payments'
          : '/api/v1/payments/booking/$bookingId',
      authenticated: true,
      query: {
        'page': page,
        'size': 10,
        'sortBy': 'createdAt',
        'sortDir': 'desc',
      },
    ),
    PaymentInfo.fromJson,
  );
  Future<PaymentInfo> payment(int id) async => PaymentInfo.fromJson(
    readMap(await _client.get('/api/v1/payments/$id', authenticated: true)),
  );
  Future<PaymentInfo> processPayment(int id, String email) async =>
      PaymentInfo.fromJson(
        readMap(
          await _client.post(
            '/api/v1/payments/$id/process',
            authenticated: true,
            query: {'recipientEmail': email},
          ),
        ),
      );
  Future<Refund> requestRefund(int paymentId, String reason) async =>
      Refund.fromJson(
        readMap(
          await _client.post(
            '/api/v1/payments/$paymentId/refund',
            authenticated: true,
            query: {'reason': reason},
          ),
        ),
      );
  Future<PagedResult<Refund>> refunds({int page = 1, String? status}) async =>
      PagedResult.fromJson(
        await _client.get(
          '/api/v1/payments/refunds',
          authenticated: true,
          query: {'page': page, 'size': 10, 'status': status},
        ),
        Refund.fromJson,
      );
  Future<Refund> refund(int id) async => Refund.fromJson(
    readMap(
      await _client.get('/api/v1/payments/refunds/$id', authenticated: true),
    ),
  );
  Future<Refund> completeRefund(
    int id,
    String transactionRef,
    String? note,
  ) async => Refund.fromJson(
    readMap(
      await _client.post(
        '/api/v1/payments/refunds/$id/complete',
        authenticated: true,
        body: {'transactionRef': transactionRef, 'note': note},
      ),
    ),
  );

  Future<PagedResult<Showtime>> showtimes({
    int page = 1,
    DateTime? start,
    DateTime? end,
  }) async => PagedResult.fromJson(
    await _client.get(
      start == null ? '/api/showtimes' : '/api/showtimes/date-range',
      authenticated: true,
      query: {
        'pageNumber': page,
        'pageSize': 10,
        'sortBy': 'startTime',
        'sortDir': 'asc',
        if (start != null) 'start': start.toIso8601String(),
        if (end != null) 'end': end.toIso8601String(),
      },
    ),
    Showtime.fromJson,
  );
  Future<Showtime> showtime(int id) async => Showtime.fromJson(
    readMap(await _client.get('/api/showtimes/$id', authenticated: true)),
  );
  Future<Showtime> saveShowtime({
    int? id,
    required int movieId,
    required int roomId,
    required DateTime start,
    required DateTime end,
    required double price,
    required String status,
  }) async {
    final body = {
      'movieId': movieId,
      'roomId': roomId,
      'startTime': start.toIso8601String(),
      'endTime': end.toIso8601String(),
      'price': price,
      'status': status,
    };
    return Showtime.fromJson(
      readMap(
        id == null
            ? await _client.post(
                '/api/showtimes',
                authenticated: true,
                body: body,
              )
            : await _client.put(
                '/api/showtimes/$id',
                authenticated: true,
                body: body,
              ),
      ),
    );
  }

  Future<Showtime> setShowtimeStatus(int id, String status) async =>
      Showtime.fromJson(
        readMap(
          await _client.patch(
            '/api/showtimes/$id/status',
            authenticated: true,
            body: {'status': status},
          ),
        ),
      );
  Future<Showtime> cancelShowtime(int id) async => Showtime.fromJson(
    readMap(await _client.delete('/api/showtimes/$id', authenticated: true)),
  );
  Future<PagedResult<Room>> rooms({int page = 1, String? keyword}) async =>
      PagedResult.fromJson(
        await _client.get(
          keyword == null || keyword.isEmpty
              ? '/api/rooms'
              : '/api/rooms/search',
          authenticated: true,
          query: {'pageNumber': page, 'pageSize': 10, 'keyword': keyword},
        ),
        Room.fromJson,
      );
  Future<Room> room(int id) async => Room.fromJson(
    readMap(await _client.get('/api/rooms/$id', authenticated: true)),
  );
  Future<List<Seat>> seats(int roomId) async => readMapList(
    await _client.get('/api/seats/room/$roomId', authenticated: true),
  ).map(Seat.fromJson).toList();
  Future<Seat> seat(int id) async => Seat.fromJson(
    readMap(await _client.get('/api/seats/$id', authenticated: true)),
  );
  Future<void> generateSeats(int roomId, int rows, int perRow) async {
    await _client.post(
      '/api/seats/generate',
      authenticated: true,
      body: {
        'roomId': roomId,
        'rows': rows,
        'seatsPerRow': perRow,
        'seatType': 'NORMAL',
      },
    );
  }

  Future<Seat> setSeatType(int id, String type) async => Seat.fromJson(
    readMap(
      await _client.put(
        '/api/seats/$id/type',
        authenticated: true,
        body: {
          'seatIds': [id],
          'seatType': type,
        },
      ),
    ),
  );
  Future<PagedResult<Movie>> movies({int page = 1}) async =>
      PagedResult.fromJson(
        await _client.get(
          '/api/v1/movies',
          authenticated: true,
          query: {'page': page, 'size': 50},
        ),
        Movie.fromJson,
      );

  Future<AppNotification> createNotification(
    Booking booking,
    String email,
    String subject,
    String content,
  ) async => AppNotification.fromJson(
    readMap(
      await _client.post(
        '/api/v1/notifications',
        authenticated: true,
        body: {
          'userId': booking.userId,
          'bookingId': booking.id,
          'recipientEmail': email,
          'subject': subject,
          'type': 'GENERAL',
          'content': content,
        },
      ),
    ),
  );
  Future<AppNotification> sendNotification(int id) async =>
      AppNotification.fromJson(
        readMap(
          await _client.post(
            '/api/v1/notifications/$id/send',
            authenticated: true,
          ),
        ),
      );
}
