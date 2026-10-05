import 'package:cinema_fe/core/network/api_exception.dart';
import 'package:cinema_fe/data/models/app_notification.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/models/movie.dart';
import 'package:cinema_fe/data/models/otp_sent_response.dart';
import 'package:cinema_fe/data/models/payment.dart';
import 'package:cinema_fe/data/models/seat.dart';
import 'package:cinema_fe/data/models/showtime.dart';
import 'package:cinema_fe/data/repositories/auth_repository.dart';
import 'package:cinema_fe/data/repositories/booking_repository.dart';
import 'package:cinema_fe/data/repositories/catalog_repository.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'fixtures.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.loginErrorMessage,
    this.registerErrorMessage,
    this.verifyErrorMessage,
    this.resetErrorMessage,
    this.delay = Duration.zero,
    AuthUser? user,
  }) : user = user ?? customerUser;

  final String? loginErrorMessage;
  final String? registerErrorMessage;
  final String? verifyErrorMessage;
  final String? resetErrorMessage;
  final Duration delay;
  final AuthUser user;

  int logoutCalls = 0;
  String? forgotPasswordEmail;
  String? resetOtp;

  Future<void> _wait() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    await _wait();
    if (loginErrorMessage != null) {
      throw ApiException(statusCode: 401, message: loginErrorMessage!);
    }
    return AuthResponse(
      accessToken: authResponseFixture.accessToken,
      refreshToken: authResponseFixture.refreshToken,
      tokenType: 'Bearer',
      expiresAt: authResponseFixture.expiresAt,
      user: user,
    );
  }

  @override
  Future<OtpSentResponse> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    await _wait();
    if (registerErrorMessage != null) {
      throw ApiException(statusCode: 400, message: registerErrorMessage!);
    }
    return OtpSentResponse(
      email: email.trim().toLowerCase(),
      message: otpResponseFixture.message,
      expiresInSeconds: otpResponseFixture.expiresInSeconds,
      resendAfterSeconds: otpResponseFixture.resendAfterSeconds,
    );
  }

  @override
  Future<AuthResponse> verifyEmail({
    required String email,
    required String otp,
    required String password,
  }) async {
    if (verifyErrorMessage != null) {
      throw ApiException(statusCode: 400, message: verifyErrorMessage!);
    }
    return authResponseFixture;
  }

  @override
  Future<OtpSentResponse> resendVerification({required String email}) async {
    return OtpSentResponse(
      email: email,
      message: 'OTP sent.',
      expiresInSeconds: 300,
      resendAfterSeconds: 60,
    );
  }

  @override
  Future<OtpSentResponse> forgotPassword({required String email}) async {
    forgotPasswordEmail = email;
    return OtpSentResponse(
      email: email,
      message: 'OTP sent.',
      expiresInSeconds: 300,
      resendAfterSeconds: 60,
    );
  }

  @override
  Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    if (resetErrorMessage != null) {
      throw ApiException(statusCode: 400, message: resetErrorMessage!);
    }
    resetOtp = otp;
    return 'Password reset.';
  }

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<AuthUser> currentUser() async => user;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({
    List<Movie>? movies,
    List<Showtime>? showtimes,
    ShowtimeSeatsData? seatMap,
    this.moviesErrorMessage,
  }) : movies = movies ?? [...movieFixtures],
       showtimes = showtimes ?? [showtimeFixture()],
       seatMap = seatMap ?? seatMapFixture;

  List<Movie> movies;
  List<Showtime> showtimes;
  ShowtimeSeatsData seatMap;
  String? moviesErrorMessage;
  int seatMapLoads = 0;

  @override
  Future<List<Movie>> getNowShowingMovies() async {
    if (moviesErrorMessage != null) {
      throw ApiException(message: moviesErrorMessage!);
    }
    return movies;
  }

  @override
  Future<List<Showtime>> getOpenShowtimes(int movieId) async {
    return showtimes.where((showtime) => showtime.movieId == movieId).toList();
  }

  @override
  Future<ShowtimeSeatsData> getSeatMap(Showtime showtime) async {
    seatMapLoads++;
    return seatMap;
  }
}

class CreateBookingCall {
  const CreateBookingCall(this.showtimeId, this.seatIds);

  final int showtimeId;
  final List<int> seatIds;
}

class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({
    List<Booking>? bookings,
    this.createError,
    PaymentInfo? verifyResult,
    this.checkoutUrl = 'https://pay.payos.vn/web/test-link',
    List<AppNotification>? notifications,
  }) : bookings = bookings ?? [],
       verifyResult = verifyResult ?? paymentFixture(),
       notifications = notifications ?? [notificationFixture];

  List<Booking> bookings;
  ApiException? createError;
  PaymentInfo verifyResult;
  String? checkoutUrl;
  List<AppNotification> notifications;
  Refund? refund;

  final createCalls = <CreateBookingCall>[];
  final cancelledIds = <int>[];
  final verifiedIds = <int>[];
  final checkoutBookingIds = <int>[];

  void _store(Booking booking) {
    bookings = [
      for (final existing in bookings)
        if (existing.id != booking.id) existing,
      booking,
    ];
  }

  @override
  Future<Booking> createBooking({
    required int showtimeId,
    required List<int> seatIds,
  }) async {
    createCalls.add(CreateBookingCall(showtimeId, seatIds));
    if (createError != null) {
      throw createError!;
    }
    final booking = bookingFixture(
      id: 200 + createCalls.length,
      seatLabels: [for (final id in seatIds) 'S$id'],
    );
    _store(booking);
    return booking;
  }

  @override
  Future<Booking> getBooking(int bookingId) async {
    return bookings.firstWhere(
      (booking) => booking.id == bookingId,
      orElse: () => throw const ApiException(
        statusCode: 404,
        message: 'Booking not found.',
      ),
    );
  }

  @override
  Future<List<Booking>> getMyBookings(int userId) async => bookings;

  @override
  Future<Booking> cancelBooking(int bookingId) async {
    cancelledIds.add(bookingId);
    final booking = await getBooking(bookingId);
    final cancelled = Booking(
      id: booking.id,
      bookingCode: booking.bookingCode,
      userId: booking.userId,
      customerEmail: booking.customerEmail,
      showtimeId: booking.showtimeId,
      status: BookingStatus.cancelled,
      totalAmount: booking.totalAmount,
      paymentId: booking.paymentId,
      movieTitle: booking.movieTitle,
      showTime: booking.showTime,
      createdAt: booking.createdAt,
      seats: booking.seats,
    );
    _store(cancelled);
    return cancelled;
  }

  @override
  Future<PayOsCheckout> startPayOsCheckout(Booking booking) async {
    checkoutBookingIds.add(booking.id);
    return PayOsCheckout(
      paymentId: 501,
      orderCode: booking.id,
      checkoutUrl: checkoutUrl,
    );
  }

  @override
  Future<PaymentInfo> verifyPayOsPayment(int bookingId) async {
    verifiedIds.add(bookingId);
    // Mirror the backend: a successful payment confirms the booking.
    if (verifyResult.status == PaymentStatus.success) {
      final booking = await getBooking(bookingId);
      _store(
        Booking(
          id: booking.id,
          bookingCode: booking.bookingCode,
          userId: booking.userId,
          customerEmail: booking.customerEmail,
          showtimeId: booking.showtimeId,
          status: BookingStatus.confirmed,
          totalAmount: booking.totalAmount,
          paymentId: verifyResult.id,
          movieTitle: booking.movieTitle,
          showTime: booking.showTime,
          createdAt: booking.createdAt,
          seats: booking.seats,
        ),
      );
    }
    return verifyResult;
  }

  @override
  Future<Refund?> getRefund(int paymentId) async => refund;

  @override
  Future<List<AppNotification>> getMyNotifications(int userId) async {
    return notifications;
  }
}

// Records the URLs the app asks url_launcher to open.
class FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final launchedUrls = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}
