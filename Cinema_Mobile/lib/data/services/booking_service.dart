import '../../core/network/api_client.dart';
import '../models/app_notification.dart';
import '../models/booking.dart';
import '../models/create_booking_request.dart';
import '../models/json_readers.dart';
import '../models/paged_result.dart';
import '../models/payment.dart';
import '../models/payos_checkout_request.dart';
import '../models/concession.dart';
import '../models/promotion.dart';
import '../models/loyalty.dart';
import '../models/review.dart';

// Bookings, PayOS payments, refunds and notifications (BookingService behind
// the gateway). Every call needs a signed-in user.
class BookingService {
  BookingService({required ApiClient client}) : _apiClient = client;

  static const pageSize = 50;

  final ApiClient _apiClient;

  Future<List<int>> getOccupiedSeatIds(int showtimeId) async {
    final response = await _apiClient.get(
      '/api/v1/bookings/showtime/$showtimeId/occupied-seats',
      authenticated: true,
    );

    if (response is! List) {
      throw const FormatException('Expected a list of seat ids.');
    }
    return response.map(readInt).toList();
  }

  // The snacks and drinks on sale.
  Future<List<ConcessionItem>> getConcessions() async {
    final response = await _apiClient.get('/api/v1/concessions');
    return readMapList(response).map(ConcessionItem.fromJson).toList();
  }

  // The average, the stars and the newest reviews of a movie (public).
  Future<MovieReviews> getMovieReviews(int movieId, {int page = 1}) async =>
      MovieReviews.fromJson(
        readMap(
          await _apiClient.get(
            '/api/v1/reviews/movie/$movieId',
            authenticated: true,
            query: {'page': page, 'size': 10},
          ),
        ),
      );

  // All ratings written by the signed-in customer.
  Future<List<MovieReview>> getMyReviews() async => readMapList(
    await _apiClient.get('/api/v1/reviews/mine', authenticated: true),
  ).map(MovieReview.fromJson).toList();

  // Whether a ticket's movie can be reviewed, and the review already written.
  Future<BookingReview> getBookingReview(int bookingId) async =>
      BookingReview.fromJson(
        readMap(
          await _apiClient.get(
            '/api/v1/reviews/booking/$bookingId',
            authenticated: true,
          ),
        ),
      );

  // Writes or changes the review of a checked-in ticket's movie.
  Future<MovieReview> saveReview({
    required int bookingId,
    required int rating,
    String comment = '',
  }) async => MovieReview.fromJson(
    readMap(
      await _apiClient.post(
        '/api/v1/reviews',
        authenticated: true,
        body: {
          'bookingId': bookingId,
          'rating': rating,
          'comment': comment.trim(),
        },
      ),
    ),
  );

  Future<void> deleteReview(int reviewId) async {
    await _apiClient.delete('/api/v1/reviews/$reviewId', authenticated: true);
  }

  // The signed-in member's points, tier and history.
  Future<LoyaltyCard> getMyLoyalty() async => LoyaltyCard.fromJson(
    readMap(await _apiClient.get('/api/v1/loyalty/me', authenticated: true)),
  );

  // The discount the tickets would get: [code] or the best automatic deal.
  Future<PromotionQuote> quotePromotion({
    required int showtimeId,
    required double ticketAmount,
    required int tickets,
    String? code,
  }) async => PromotionQuote.fromJson(
    readMap(
      await _apiClient.post(
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

  Future<Booking> createBooking(CreateBookingRequest request) async {
    final response = await _apiClient.post(
      '/api/v1/bookings',
      body: request.toJson(),
      authenticated: true,
    );

    return Booking.fromJson(readMap(response));
  }

  Future<Booking> updateBooking(
    int bookingId,
    CreateBookingRequest request,
  ) async => Booking.fromJson(
    readMap(
      await _apiClient.put(
        '/api/v1/bookings/$bookingId/details',
        body: request.toJson(),
        authenticated: true,
      ),
    ),
  );

  Future<Booking> getBooking(int bookingId) async {
    final response = await _apiClient.get(
      '/api/v1/bookings/$bookingId',
      authenticated: true,
    );

    return Booking.fromJson(readMap(response));
  }

  Future<PagedResult<Booking>> getBookingsByUser(
    int userId, {
    int page = 1,
    int size = pageSize,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/bookings/user/$userId',
      query: {
        'page': page,
        'size': size,
        'sortBy': 'createdAt',
        'sortDir': 'desc',
      },
      authenticated: true,
    );

    return PagedResult.fromJson(response, Booking.fromJson);
  }

  Future<PagedResult<PaymentInfo>> getPaymentsByUser(
    int userId, {
    int page = 1,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/payments/user/$userId',
      query: {
        'page': page,
        'size': pageSize,
        'sortBy': 'createdAt',
        'sortDir': 'desc',
      },
      authenticated: true,
    );
    return PagedResult.fromJson(response, PaymentInfo.fromJson);
  }

  Future<Booking> cancelBooking(int bookingId, {String? reason}) async {
    final response = await _apiClient.post(
      '/api/v1/bookings/$bookingId/cancel',
      query: {'reason': reason},
      authenticated: true,
    );

    return Booking.fromJson(readMap(response));
  }

  Future<PayOsCheckout> createPayOsCheckout(
    PayOsCheckoutRequest request,
  ) async {
    final response = await _apiClient.post(
      '/api/v1/payments/payos/checkout',
      body: request.toJson(),
      authenticated: true,
    );

    return PayOsCheckout.fromJson(readMap(response));
  }

  // Asks PayOS for the payment result. A paid order confirms the booking and
  // a cancelled one releases its seats; calling it again is safe. Takes the
  // PayOS order code or the booking id.
  Future<PaymentInfo> verifyPayOsPayment(int orderCode) async {
    final response = await _apiClient.post(
      '/api/v1/payments/payos/$orderCode/verify',
      authenticated: true,
    );

    return PaymentInfo.fromJson(readMap(response));
  }

  Future<Refund> getRefundOfPayment(int paymentId) async {
    final response = await _apiClient.get(
      '/api/v1/payments/$paymentId/refund',
      authenticated: true,
    );

    return Refund.fromJson(readMap(response));
  }

  Future<PagedResult<AppNotification>> getNotificationsByUser(
    int userId, {
    int page = 1,
    int size = pageSize,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/notifications/user/$userId',
      query: {
        'page': page,
        'size': size,
        'sortBy': 'createdAt',
        'sortDir': 'desc',
      },
      authenticated: true,
    );

    return PagedResult.fromJson(response, AppNotification.fromJson);
  }

  Future<int> getUnreadNotificationCount() async => readInt(
    readMap(
      await _apiClient.get(
        '/api/v1/notifications/unread-count',
        authenticated: true,
      ),
    )['count'],
  );

  Future<AppNotification> markNotificationRead(int id) async =>
      AppNotification.fromJson(
        readMap(
          await _apiClient.patch(
            '/api/v1/notifications/$id/read',
            authenticated: true,
          ),
        ),
      );

  Future<void> markAllNotificationsRead() async {
    await _apiClient.post(
      '/api/v1/notifications/read-all',
      authenticated: true,
    );
  }

  Future<AppNotification> getNotification(int id) async {
    final response = await _apiClient.get(
      '/api/v1/notifications/$id',
      authenticated: true,
    );
    return AppNotification.fromJson(readMap(response));
  }
}
