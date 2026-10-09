import '../../core/network/api_client.dart';
import '../models/app_notification.dart';
import '../models/booking.dart';
import '../models/create_booking_request.dart';
import '../models/json_readers.dart';
import '../models/paged_result.dart';
import '../models/payment.dart';
import '../models/payos_checkout_request.dart';

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

  Future<Booking> createBooking(CreateBookingRequest request) async {
    final response = await _apiClient.post(
      '/api/v1/bookings',
      body: request.toJson(),
      authenticated: true,
    );

    return Booking.fromJson(readMap(response));
  }

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
  // a cancelled one releases its seats; calling it again is safe.
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
}
