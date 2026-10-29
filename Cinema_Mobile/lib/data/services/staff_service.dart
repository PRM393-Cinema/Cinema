import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../models/app_notification.dart';
import '../models/booking.dart';
import '../models/json_readers.dart';
import '../models/movie.dart';
import '../models/movie_draft.dart';
import '../models/paged_result.dart';
import '../models/payment.dart';
import '../models/room.dart';
import '../models/seat.dart';
import '../models/showtime.dart';
import '../models/concession.dart';
import '../models/promotion.dart';
import '../models/loyalty.dart';
import '../models/review.dart';

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
  // The booking a ticket code (the QR code on the customer's ticket) belongs
  // to.
  Future<Booking> bookingByCode(String code) async => Booking.fromJson(
    readMap(
      await _client.get(
        '/api/v1/bookings/code/${Uri.encodeComponent(code.trim())}',
        authenticated: true,
      ),
    ),
  );
  // Checks a paid ticket in at the cinema; the server refuses a used ticket,
  // an unpaid one and one for a show that is not close to starting.
  Future<Booking> checkIn(int id) async => Booking.fromJson(
    readMap(
      await _client.post('/api/v1/bookings/$id/check-in', authenticated: true),
    ),
  );
  // Seats of a showtime that bookings hold or have sold.
  Future<List<ShowtimeSeatBooking>> showtimeSeatBookings(
    int showtimeId,
  ) async => readMapList(
    await _client.get(
      '/api/v1/bookings/showtime/$showtimeId/seats',
      authenticated: true,
    ),
  ).map(ShowtimeSeatBooking.fromJson).toList();
  // Holds seats at the counter for a customer account, or for a walk-in guest
  // without one ([userId] null) who may leave an email and a phone number.
  Future<Booking> createBooking({
    int? userId,
    String? email,
    String? phone,
    required int showtimeId,
    required List<int> seats,
    Map<int, int> concessions = const {},
    String? promotionCode,
    int usePoints = 0,
  }) async => Booking.fromJson(
    readMap(
      await _client.post(
        '/api/v1/bookings',
        authenticated: true,
        body: {
          'userId': ?userId,
          'customerEmail': ?email,
          'customerPhone': ?phone,
          'showtimeId': showtimeId,
          'seats': [
            for (final id in seats) {'seatId': id},
          ],
          'promotionCode': ?promotionCode,
          if (usePoints > 0) 'usePoints': usePoints,
          'concessions': [
            for (final MapEntry(key: itemId, value: quantity)
                in concessions.entries)
              if (quantity > 0) {'itemId': itemId, 'quantity': quantity},
          ],
        },
      ),
    ),
  );
  // The discount the counter's tickets would get: [code] or the best
  // automatic deal.
  Future<PromotionQuote> quotePromotion({
    required int showtimeId,
    required double ticketAmount,
    required int tickets,
    String? code,
  }) async => PromotionQuote.fromJson(
    readMap(
      await _client.post(
        '/api/v1/promotions/quote',
        authenticated: true,
        body: {
          'showtimeId': showtimeId,
          'ticketAmount': ticketAmount,
          'tickets': tickets,
          'code': ?code,
        },
      ),
    ),
  );
  // Admin: the reviews of a movie, to remove unsuitable ones.
  Future<MovieReviews> movieReviews(int movieId, {int page = 1}) async =>
      MovieReviews.fromJson(
        readMap(
          await _client.get(
            '/api/v1/reviews/movie/$movieId',
            authenticated: true,
            query: {'page': page, 'size': 50},
          ),
        ),
      );
  Future<void> deleteReview(int reviewId) async {
    await _client.delete('/api/v1/reviews/$reviewId', authenticated: true);
  }

  // Customer accounts with this phone number (separators are ignored).
  Future<List<MemberLookup>> findMembers(String phone) async => readMapList(
    await _client.get(
      '/api/v1/auth/members',
      authenticated: true,
      query: {'phone': phone.trim()},
    ),
  ).map(MemberLookup.fromJson).toList();
  // A member's points, tier and history.
  Future<LoyaltyCard> loyalty(int userId) async => LoyaltyCard.fromJson(
    readMap(
      await _client.get('/api/v1/loyalty/users/$userId', authenticated: true),
    ),
  );
  // Points and tiers of several members (no history).
  Future<List<LoyaltyCard>> loyaltyAccounts(List<int> userIds) async =>
      readMapList(
        await _client.get(
          '/api/v1/loyalty/accounts',
          authenticated: true,
          query: {'userIds': userIds.join(',')},
        ),
      ).map(LoyaltyCard.fromJson).toList();
  // Admin: adds (positive) or takes away (negative) points, with a reason.
  Future<LoyaltyCard> adjustPoints(
    int userId, {
    required int points,
    required String note,
  }) async => LoyaltyCard.fromJson(
    readMap(
      await _client.post(
        '/api/v1/loyalty/users/$userId/adjust',
        authenticated: true,
        body: {'points': points, 'note': note.trim()},
      ),
    ),
  );
  // Admin: every promotion, also promo codes and ended ones.
  Future<List<Promotion>> promotions() async => readMapList(
    await _client.get(
      '/api/v1/promotions',
      authenticated: true,
      query: {'all': true},
    ),
  ).map(Promotion.fromJson).toList();
  // Admin: adds a promotion ([id] null) or changes one. [code] empty: applied
  // automatically.
  Future<Promotion> savePromotion({
    int? id,
    String code = '',
    required String name,
    String description = '',
    required String discountType,
    required double discountValue,
    double? maxDiscount,
    int minTickets = 1,
    List<int> daysOfWeek = const [],
    DateTime? startsAt,
    DateTime? endsAt,
    int? usageLimit,
    bool active = true,
  }) async {
    final body = {
      'code': code.trim().isEmpty ? null : code.trim().toUpperCase(),
      'name': name.trim(),
      'description': description.trim(),
      'discountType': discountType,
      'discountValue': discountValue,
      'maxDiscount': maxDiscount,
      'minTickets': minTickets,
      'daysOfWeek': daysOfWeek,
      'startsAt': startsAt?.toIso8601String(),
      'endsAt': endsAt?.toIso8601String(),
      'usageLimit': usageLimit,
      'active': active,
    };
    return Promotion.fromJson(
      readMap(
        id == null
            ? await _client.post(
                '/api/v1/promotions',
                authenticated: true,
                body: body,
              )
            : await _client.put(
                '/api/v1/promotions/$id',
                authenticated: true,
                body: body,
              ),
      ),
    );
  }

  // The snacks menu; [includeInactive] adds stopped items (staff/admin).
  Future<List<ConcessionItem>> concessions({
    bool includeInactive = false,
  }) async => readMapList(
    await _client.get(
      '/api/v1/concessions',
      authenticated: true,
      query: {'includeInactive': includeInactive},
    ),
  ).map(ConcessionItem.fromJson).toList();
  // Admin: adds a menu item ([id] null) or changes one.
  Future<ConcessionItem> saveConcession({
    int? id,
    required String name,
    required double price,
    String description = '',
    String imageUrl = '',
    int sortOrder = 0,
    bool active = true,
  }) async {
    final body = {
      'name': name.trim(),
      'price': price,
      'description': description.trim(),
      'imageUrl': imageUrl.trim(),
      'sortOrder': sortOrder,
      'active': active,
    };
    return ConcessionItem.fromJson(
      readMap(
        id == null
            ? await _client.post(
                '/api/v1/concessions',
                authenticated: true,
                body: body,
              )
            : await _client.put(
                '/api/v1/concessions/$id',
                authenticated: true,
                body: body,
              ),
      ),
    );
  }

  // Cash taken at the counter: the server records a paid CASH payment and
  // confirms the ticket, emailing it (with its QR code) when there is an
  // email.
  Future<PaymentInfo> payCash(
    int bookingId,
    double amountReceived, {
    String? email,
  }) async => PaymentInfo.fromJson(
    readMap(
      await _client.post(
        '/api/v1/payments/cash',
        authenticated: true,
        body: {
          'bookingId': bookingId,
          'amountReceived': amountReceived,
          'recipientEmail': ?email,
        },
      ),
    ),
  );
  // A PayOS bank transfer the customer pays at the counter by scanning its
  // QR code. Asking again returns the link already made.
  Future<PayOsCheckout> counterTransfer(Booking booking) async =>
      PayOsCheckout.fromJson(
        readMap(
          await _client.post(
            '/api/v1/payments/payos/checkout',
            authenticated: true,
            body: {
              'bookingId': booking.id,
              'amount': booking.totalAmount,
              'description': booking.bookingCode.length > 25
                  ? booking.bookingCode.substring(
                      booking.bookingCode.length - 25,
                    )
                  : booking.bookingCode,
              'returnUrl': ApiConfig.paymentReturnUrl,
              'cancelUrl': ApiConfig.paymentReturnUrl,
            },
          ),
        ),
      );
  // Asks PayOS whether the transfer arrived; a paid one confirms the ticket.
  Future<PaymentInfo> verifyTransfer(int orderCode, {String? email}) async =>
      PaymentInfo.fromJson(
        readMap(
          await _client.post(
            '/api/v1/payments/payos/$orderCode/verify',
            authenticated: true,
            query: {'recipientEmail': ?email},
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
  // Admin: money received for tickets between [start] and [end].
  Future<PaymentSummary> paymentSummary(DateTime start, DateTime end) async =>
      PaymentSummary.fromJson(
        readMap(
          await _client.get(
            '/api/v1/payments/summary',
            authenticated: true,
            query: {
              'start': start.toIso8601String(),
              'end': end.toIso8601String(),
            },
          ),
        ),
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
  Future<Refund> refundOfPayment(int paymentId) async => Refund.fromJson(
    readMap(
      await _client.get(
        '/api/v1/payments/$paymentId/refund',
        authenticated: true,
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
  Future<Refund> rejectRefund(int id, String reason) async => Refund.fromJson(
    readMap(
      await _client.post(
        '/api/v1/payments/refunds/$id/reject',
        authenticated: true,
        body: {'reason': reason},
      ),
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
    int size = 10,
  }) async => PagedResult.fromJson(
    await _client.get(
      start == null ? '/api/showtimes' : '/api/showtimes/date-range',
      authenticated: true,
      query: {
        'pageNumber': page,
        'pageSize': size,
        'sortBy': 'startTime',
        'sortDir': 'asc',
        if (start != null) 'start': start.toIso8601String(),
        if (end != null) 'end': end.toIso8601String(),
      },
    ),
    Showtime.fromJson,
  );
  // Every showtime starting in [start, end), in start order (pages of 50).
  Future<List<Showtime>> showtimesBetween(DateTime start, DateTime end) async {
    final all = <Showtime>[];
    for (var page = 1; ; page++) {
      final result = await showtimes(
        page: page,
        start: start,
        end: end,
        size: 50,
      );
      all.addAll(result.items);
      if (page >= result.totalPages) return all;
    }
  }

  // Seats sold, held and checked in for each showtime that has tickets: the
  // given showtimes, or those starting in [start, end).
  Future<List<ShowtimeBookingStats>> showtimeStats({
    List<int>? ids,
    DateTime? start,
    DateTime? end,
  }) async => readMapList(
    await _client.get(
      '/api/v1/bookings/showtimes/stats',
      authenticated: true,
      query: {
        'showtimeIds': ?ids,
        if (start != null) 'start': start.toIso8601String(),
        if (end != null) 'end': end.toIso8601String(),
      },
    ),
  ).map(ShowtimeBookingStats.fromJson).toList();

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
    String format = '2D',
  }) async {
    final body = {
      'movieId': movieId,
      'roomId': roomId,
      'startTime': start.toIso8601String(),
      'endTime': end.toIso8601String(),
      'price': price,
      'status': status,
      'format': format,
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
  Future<PagedResult<Room>> rooms({
    int page = 1,
    String? keyword,
    int size = 10,
  }) async => PagedResult.fromJson(
    await _client.get(
      keyword == null || keyword.isEmpty ? '/api/rooms' : '/api/rooms/search',
      authenticated: true,
      query: {'pageNumber': page, 'pageSize': size, 'keyword': keyword},
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

  // Gives many seats of a room one type at once (a sweetbox brings its pair);
  // returns the new seat map.
  Future<List<Seat>> setSeatTypes(
    int roomId,
    List<int> seatIds,
    String type,
  ) async => readMapList(
    await _client.put(
      '/api/seats/room/$roomId/types',
      authenticated: true,
      body: {'seatIds': seatIds, 'seatType': type},
    ),
  ).map(Seat.fromJson).toList();

  // Admin: new seats fill the last row up to [seatsPerRow] (default: the
  // widest row), then the next rows; fewer seats remove the last ones. The
  // existing seats keep their labels. Returns the new seat map.
  Future<List<Seat>> setRoomSeatCount(
    int roomId,
    int totalSeats, {
    int? seatsPerRow,
  }) async => readMapList(
    await _client.put(
      '/api/seats/room/$roomId/capacity',
      authenticated: true,
      body: {'totalSeats': totalSeats, 'seatsPerRow': ?seatsPerRow},
    ),
  ).map(Seat.fromJson).toList();

  Future<Movie> movie(int id) async => Movie.fromJson(
    readMap(await _client.get('/api/v1/movies/$id', authenticated: true)),
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

  // ----- Admin: movies -----

  // All movies, newest first; a keyword searches titles, a status (ACTIVE /
  // INACTIVE) filters the list.
  Future<PagedResult<Movie>> catalogMovies({
    int page = 1,
    int size = 10,
    String? keyword,
    String? status,
  }) async {
    final search = keyword?.trim() ?? '';
    return PagedResult.fromJson(
      await _client.get(
        search.isNotEmpty
            ? '/api/v1/movies/search'
            : status != null
            ? '/api/v1/movies/status/$status'
            : '/api/v1/movies',
        authenticated: true,
        query: {
          'page': page,
          'size': size,
          'sortBy': 'createdAt',
          'sortDir': 'desc',
          if (search.isNotEmpty) 'keyword': search,
        },
      ),
      Movie.fromJson,
    );
  }

  Future<Movie> createMovie(MovieDraft draft) async => Movie.fromJson(
    readMap(
      await _client.post(
        '/api/v1/movies',
        authenticated: true,
        body: draft.toJson(),
      ),
    ),
  );

  // A status of ACTIVE shows a stopped movie again; null keeps the status.
  Future<Movie> updateMovie(int id, MovieDraft draft, {String? status}) async =>
      Movie.fromJson(
        readMap(
          await _client.put(
            '/api/v1/movies/$id',
            authenticated: true,
            body: {...draft.toJson(), 'status': ?status},
          ),
        ),
      );

  // The API keeps the movie and marks it INACTIVE.
  Future<void> stopShowingMovie(int id) async {
    await _client.delete('/api/v1/movies/$id', authenticated: true);
  }

  // ----- Admin: rooms -----

  // Creates the room only; its seats come from generateSeats.
  Future<Room> createRoom({
    required String name,
    required int rows,
    required int seatsPerRow,
  }) async => Room.fromJson(
    readMap(
      await _client.post(
        '/api/rooms',
        authenticated: true,
        body: {
          'name': name.trim(),
          'totalSeats': rows * seatsPerRow,
          'rows': rows,
          'seatsPerRow': seatsPerRow,
        },
      ),
    ),
  );

  // The API keeps the real seat count of a room that has seats, so the row
  // values only describe the current capacity.
  Future<Room> renameRoom(Room room, String name) async {
    final seats = room.totalSeats < 1 ? 1 : room.totalSeats;
    return Room.fromJson(
      readMap(
        await _client.put(
          '/api/rooms/${room.id}',
          authenticated: true,
          body: {
            'name': name.trim(),
            'totalSeats': seats,
            'rows': 1,
            'seatsPerRow': seats,
          },
        ),
      ),
    );
  }

  // Refused by the API while the room has showtimes.
  Future<void> deleteRoom(int id) async {
    await _client.delete('/api/rooms/$id', authenticated: true);
  }

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
