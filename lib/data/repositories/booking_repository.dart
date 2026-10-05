import '../../core/network/api_config.dart';
import '../../core/network/api_exception.dart';
import '../models/app_notification.dart';
import '../models/booking.dart';
import '../models/create_booking_request.dart';
import '../models/payment.dart';
import '../models/payos_checkout_request.dart';
import '../services/booking_service.dart';

abstract interface class BookingRepository {
  // Holds the seats for 10 minutes; the booking stays PENDING until paid.
  Future<Booking> createBooking({
    required int showtimeId,
    required List<int> seatIds,
  });

  Future<Booking> getBooking(int bookingId);

  Future<List<Booking>> getMyBookings(int userId);

  Future<Booking> cancelBooking(int bookingId);

  Future<PayOsCheckout> startPayOsCheckout(Booking booking);

  Future<PaymentInfo> verifyPayOsPayment(int bookingId);

  // The refund of a cancelled paid booking, or null when there is none.
  Future<Refund?> getRefund(int paymentId);

  Future<List<AppNotification>> getMyNotifications(int userId);
}

class RemoteBookingRepository implements BookingRepository {
  RemoteBookingRepository({required BookingService service})
    : _bookingService = service;

  final BookingService _bookingService;

  @override
  Future<Booking> createBooking({
    required int showtimeId,
    required List<int> seatIds,
  }) {
    return _bookingService.createBooking(
      CreateBookingRequest(showtimeId: showtimeId, seatIds: seatIds),
    );
  }

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
    // The PayOS order code is the booking id.
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
    final result = await _bookingService.getNotificationsByUser(userId);
    return result.items;
  }
}
