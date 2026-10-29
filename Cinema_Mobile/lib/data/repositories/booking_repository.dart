import '../../core/network/api_config.dart';
import '../../core/network/api_exception.dart';
import '../models/app_notification.dart';
import '../models/booking.dart';
import '../models/create_booking_request.dart';
import '../models/payment.dart';
import '../models/payos_checkout_request.dart';
import '../services/booking_service.dart';
import '../models/concession.dart';
import '../models/promotion.dart';
import '../models/loyalty.dart';
import '../models/review.dart';

abstract interface class BookingRepository {
  // Holds the seats for 10 minutes; the booking stays PENDING until paid.
  // [concessions] maps snack item ids to quantities; [promotionCode] is a
  // promo code typed in (none: the best automatic deal applies).
  Future<Booking> createBooking({
    required int showtimeId,
    required List<int> seatIds,
    Map<int, int> concessions = const {},
    String? promotionCode,
    int usePoints = 0,
  });

  // Updates extras on the held order without extending its deadline.
  Future<Booking> updateBooking(int bookingId, CreateBookingRequest request);

  // The signed-in member's points, tier and history.
  Future<LoyaltyCard> getMyLoyalty();

  // Reviews of a ticket's movie: allowed once the ticket was checked in.
  Future<BookingReview> getBookingReview(int bookingId);

  // Every rating the signed-in customer wrote.
  Future<List<MovieReview>> getMyReviews();

  Future<MovieReview> saveReview({
    required int bookingId,
    required int rating,
    String comment = '',
  });

  Future<void> deleteReview(int reviewId);

  // The discount the tickets would get, before they are held.
  Future<PromotionQuote> quotePromotion({
    required int showtimeId,
    required double ticketAmount,
    required int tickets,
    String? code,
  });

  // The snacks and drinks menu.
  Future<List<ConcessionItem>> getConcessions();

  Future<Booking> getBooking(int bookingId);

  Future<List<Booking>> getMyBookings(int userId);

  Future<List<PaymentInfo>> getMyPayments(int userId);

  Future<Booking> cancelBooking(int bookingId);

  Future<PayOsCheckout> startPayOsCheckout(Booking booking);

  Future<PaymentInfo> verifyPayOsPayment(int bookingId);

  // The refund of a cancelled paid booking, or null when there is none.
  Future<Refund?> getRefund(int paymentId);

  Future<List<AppNotification>> getMyNotifications(int userId);

  Future<AppNotification> getNotification(int id);

  // Notifications not opened yet (the badge on the bell).
  Future<int> getUnreadNotificationCount();

  Future<AppNotification> markNotificationRead(int id);

  Future<void> markAllNotificationsRead();
}

class RemoteBookingRepository implements BookingRepository {
  RemoteBookingRepository({required BookingService service})
    : _bookingService = service;

  final BookingService _bookingService;

  @override
  Future<Booking> updateBooking(int bookingId, CreateBookingRequest request) =>
      _bookingService.updateBooking(bookingId, request);

  @override
  Future<Booking> createBooking({
    required int showtimeId,
    required List<int> seatIds,
    Map<int, int> concessions = const {},
    String? promotionCode,
    int usePoints = 0,
  }) {
    return _bookingService.createBooking(
      CreateBookingRequest(
        showtimeId: showtimeId,
        seatIds: seatIds,
        concessions: concessions,
        promotionCode: promotionCode,
        usePoints: usePoints,
      ),
    );
  }

  @override
  Future<LoyaltyCard> getMyLoyalty() => _bookingService.getMyLoyalty();

  @override
  Future<BookingReview> getBookingReview(int bookingId) =>
      _bookingService.getBookingReview(bookingId);

  @override
  Future<List<MovieReview>> getMyReviews() => _bookingService.getMyReviews();

  @override
  Future<MovieReview> saveReview({
    required int bookingId,
    required int rating,
    String comment = '',
  }) => _bookingService.saveReview(
    bookingId: bookingId,
    rating: rating,
    comment: comment,
  );

  @override
  Future<void> deleteReview(int reviewId) =>
      _bookingService.deleteReview(reviewId);

  @override
  Future<PromotionQuote> quotePromotion({
    required int showtimeId,
    required double ticketAmount,
    required int tickets,
    String? code,
  }) => _bookingService.quotePromotion(
    showtimeId: showtimeId,
    ticketAmount: ticketAmount,
    tickets: tickets,
    code: code,
  );

  @override
  Future<List<ConcessionItem>> getConcessions() =>
      _bookingService.getConcessions();

  @override
  Future<Booking> getBooking(int bookingId) {
    return _bookingService.getBooking(bookingId);
  }

  @override
  Future<List<Booking>> getMyBookings(int userId) async {
    final result = await _bookingService.getBookingsByUser(userId);
    return result.items;
  }

  @override
  Future<List<PaymentInfo>> getMyPayments(int userId) async {
    final payments = <PaymentInfo>[];
    var result = await _bookingService.getPaymentsByUser(userId);
    payments.addAll(result.items);
    for (var page = 2; page <= result.totalPages; page++) {
      result = await _bookingService.getPaymentsByUser(userId, page: page);
      payments.addAll(result.items);
    }
    return payments;
  }

  @override
  Future<Booking> cancelBooking(int bookingId) {
    return _bookingService.cancelBooking(
      bookingId,
      reason: 'Cancelled by customer in the app',
    );
  }

  @override
  Future<PayOsCheckout> startPayOsCheckout(Booking booking) {
    final returnUrl = ApiConfig.paymentReturnUrl;
    return _bookingService.createPayOsCheckout(
      PayOsCheckoutRequest(
        bookingId: booking.id,
        amount: booking.totalAmount,
        returnUrl: returnUrl,
        cancelUrl: returnUrl,
      ),
    );
  }

  @override
  Future<PaymentInfo> verifyPayOsPayment(int bookingId) {
    // The server takes the PayOS order code or the booking id and checks the
    // booking's PayOS payment.
    return _bookingService.verifyPayOsPayment(bookingId);
  }

  @override
  Future<Refund?> getRefund(int paymentId) async {
    try {
      return await _bookingService.getRefundOfPayment(paymentId);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<List<AppNotification>> getMyNotifications(int userId) async {
    var result = await _bookingService.getNotificationsByUser(userId);
    final notifications = [...result.items];
    for (var page = 2; page <= result.totalPages; page++) {
      result = await _bookingService.getNotificationsByUser(userId, page: page);
      notifications.addAll(result.items);
    }
    return notifications;
  }

  @override
  Future<AppNotification> getNotification(int id) =>
      _bookingService.getNotification(id);

  @override
  Future<int> getUnreadNotificationCount() =>
      _bookingService.getUnreadNotificationCount();

  @override
  Future<AppNotification> markNotificationRead(int id) =>
      _bookingService.markNotificationRead(id);

  @override
  Future<void> markAllNotificationsRead() =>
      _bookingService.markAllNotificationsRead();
}
