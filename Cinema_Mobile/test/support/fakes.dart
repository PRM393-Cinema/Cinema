import 'package:cinema_fe/core/network/api_exception.dart';
import 'package:cinema_fe/data/models/app_notification.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/models/create_booking_request.dart';
import 'package:cinema_fe/data/models/movie.dart';
import 'package:cinema_fe/data/models/otp_sent_response.dart';
import 'package:cinema_fe/data/models/payment.dart';
import 'package:cinema_fe/data/models/paged_result.dart';
import 'package:cinema_fe/data/models/seat.dart';
import 'package:cinema_fe/data/models/showtime.dart';
import 'package:cinema_fe/data/repositories/auth_repository.dart';
import 'package:cinema_fe/data/repositories/booking_repository.dart';
import 'package:cinema_fe/data/repositories/catalog_repository.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'fixtures.dart';

import 'package:cinema_fe/data/models/concession.dart';
import 'package:cinema_fe/data/models/promotion.dart';
import 'package:cinema_fe/data/models/loyalty.dart';
import 'package:cinema_fe/data/models/review.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<PagedResult<AuthUser>> users({
    int page = 1,
    String? keyword,
    String? role,
    bool? enabled,
  }) async =>
      throw UnsupportedError('Admin API is not configured in this fake.');
  @override
  Future<AuthUser> getUser(int id) async =>
      throw UnsupportedError('Admin API is not configured in this fake.');
  @override
  Future<List<String>> roles() async =>
      throw UnsupportedError('Admin API is not configured in this fake.');
  @override
  Future<AuthUser> createUser({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required List<String> roles,
  }) async =>
      throw UnsupportedError('Admin API is not configured in this fake.');
  @override
  Future<AuthUser> updateUserRoles(int id, List<String> roles) async =>
      throw UnsupportedError('Admin API is not configured in this fake.');
  @override
  Future<AuthUser> updateUserStatus(int id, bool enabled) async =>
      throw UnsupportedError('Admin API is not configured in this fake.');
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
  AuthUser user;

  int logoutCalls = 0;
  int registerCalls = 0;
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
    registerCalls++;
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

  // Profile edits and password changes the screens sent.
  final profileUpdates = <({String fullName, String phone})>[];
  final passwordChanges = <({String current, String next})>[];

  // The current password the fake accepts.
  String currentPassword = 'Secret@123';

  @override
  Future<AuthUser> updateProfile({
    required String fullName,
    String phone = '',
  }) async {
    profileUpdates.add((fullName: fullName, phone: phone));
    user = AuthUser.fromJson({
      ...user.toJson(),
      'fullName': fullName,
      'phone': phone.isEmpty ? null : phone,
    });
    return user;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    passwordChanges.add((current: currentPassword, next: newPassword));
    if (currentPassword != this.currentPassword) {
      throw const ApiException(
        statusCode: 400,
        message: 'Current password is incorrect.',
      );
    }
    this.currentPassword = newPassword;
  }

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

  // The filters the home screen asked for, newest last.
  final browseCalls = <({bool comingSoon, String? genre, String? keyword})>[];

  // Like the API: active movies, released or not yet, by genre and title.
  @override
  Future<List<Movie>> browseMovies({
    bool comingSoon = false,
    String? genre,
    String? keyword,
  }) async {
    browseCalls.add((comingSoon: comingSoon, genre: genre, keyword: keyword));
    if (moviesErrorMessage != null) {
      throw ApiException(message: moviesErrorMessage!);
    }
    return [
      for (final movie in movies)
        if (movie.status == 'ACTIVE' &&
            movie.isComingSoon() == comingSoon &&
            (genre == null ||
                movie.genre.toLowerCase().contains(genre.toLowerCase())) &&
            (keyword == null ||
                movie.title.toLowerCase().contains(keyword.toLowerCase())))
          movie,
    ];
  }

  // Reviews per movie id; none by default.
  final reviews = <int, MovieReviews>{};

  @override
  Future<MovieReviews> getMovieReviews(int movieId) async =>
      reviews[movieId] ?? MovieReviews.empty;

  @override
  Future<List<String>> getGenres() async => {
    for (final movie in movies)
      for (final genre in movie.genre.split(','))
        if (genre.trim().isNotEmpty) genre.trim(),
  }.toList();

  @override
  Future<Movie> getMovie(int movieId) async {
    return movies.firstWhere(
      (movie) => movie.id == movieId,
      orElse: () =>
          throw const ApiException(message: 'Movie not found', statusCode: 404),
    );
  }

  @override
  Future<Showtime> getShowtime(int showtimeId) async {
    return showtimes.firstWhere(
      (showtime) => showtime.id == showtimeId,
      orElse: () => throw const ApiException(
        message: 'Showtime not found',
        statusCode: 404,
      ),
    );
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
  const CreateBookingCall(
    this.showtimeId,
    this.seatIds, [
    this.concessions = const {},
    this.promotionCode,
    this.usePoints = 0,
  ]);

  final int showtimeId;
  final List<int> seatIds;
  final Map<int, int> concessions;
  final String? promotionCode;
  final int usePoints;
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
  DateTime? holdExpiresAt;
  PaymentInfo verifyResult;
  String? checkoutUrl;
  List<AppNotification> notifications;
  Refund? refund;

  final createCalls = <CreateBookingCall>[];
  final updateCalls = <CreateBookingCall>[];

  @override
  Future<Booking> updateBooking(
    int bookingId,
    CreateBookingRequest request,
  ) async {
    updateCalls.add(
      CreateBookingCall(
        request.showtimeId,
        request.seatIds,
        request.concessions,
        request.promotionCode,
        request.usePoints,
      ),
    );
    return getBooking(bookingId);
  }

  final cancelledIds = <int>[];
  final verifiedIds = <int>[];
  final checkoutBookingIds = <int>[];

  // The snacks menu the summary offers.
  List<ConcessionItem> snacks = const [];

  @override
  Future<List<ConcessionItem>> getConcessions() async => snacks;

  // Promo codes that work, and the automatic deal (none by default). An
  // unknown code is refused like the API does.
  final promoCodes = <String, PromotionQuote>{};
  PromotionQuote automaticDeal = PromotionQuote.none;
  final quoteCodes = <String?>[];

  // The member's card; null makes loading it fail (no points used then).
  LoyaltyCard? loyalty;

  // The review state of each ticket; a ticket not listed cannot be reviewed.
  final bookingReviews = <int, BookingReview>{};
  final savedReviews = <({int bookingId, int rating, String comment})>[];
  final deletedReviews = <int>[];
  List<MovieReview> myReviews = [];

  @override
  Future<List<MovieReview>> getMyReviews() async => myReviews;

  @override
  Future<BookingReview> getBookingReview(int bookingId) async =>
      bookingReviews[bookingId] ??
      BookingReview(bookingId: bookingId, movieId: 0, canReview: false);

  @override
  Future<MovieReview> saveReview({
    required int bookingId,
    required int rating,
    String comment = '',
  }) async {
    savedReviews.add((bookingId: bookingId, rating: rating, comment: comment));
    final now = DateTime.now();
    return MovieReview(
      id: 500 + savedReviews.length,
      movieId: bookingReviews[bookingId]?.movieId ?? 1,
      bookingId: bookingId,
      reviewerName: 'Nguyen Van Khach',
      rating: rating,
      comment: comment.isEmpty ? null : comment,
      createdAt: now,
      updatedAt: now,
      mine: true,
    );
  }

  @override
  Future<void> deleteReview(int reviewId) async => deletedReviews.add(reviewId);

  @override
  Future<LoyaltyCard> getMyLoyalty() async =>
      loyalty ??
      (throw const ApiException(statusCode: 503, message: 'No points.'));

  @override
  Future<PromotionQuote> quotePromotion({
    required int showtimeId,
    required double ticketAmount,
    required int tickets,
    String? code,
  }) async {
    quoteCodes.add(code);
    if (code == null) return automaticDeal;
    return promoCodes[code] ??
        (throw ApiException(
          statusCode: 400,
          message: 'Promo code $code is not valid.',
        ));
  }

  // PayOS order codes and their bookings; verify takes either, like the API.
  final orderCodes = <int, int>{};

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
    Map<int, int> concessions = const {},
    String? promotionCode,
    int usePoints = 0,
  }) async {
    createCalls.add(
      CreateBookingCall(
        showtimeId,
        seatIds,
        concessions,
        promotionCode,
        usePoints,
      ),
    );
    if (createError != null) {
      throw createError!;
    }
    final booking = bookingFixture(
      id: 200 + createCalls.length,
      expiresAt: holdExpiresAt,
      seatLabels: [for (final id in seatIds) 'S$id'],
    );
    _store(booking);
    return booking;
  }

  // Notifications opened (marked read) and "Mark all read" taps.
  final readNotificationIds = <int>[];
  int markAllReadCalls = 0;

  @override
  Future<int> getUnreadNotificationCount() async =>
      notifications.where((n) => !n.isRead).length;

  @override
  Future<AppNotification> markNotificationRead(int id) async {
    readNotificationIds.add(id);
    notifications = [
      for (final n in notifications)
        n.id == id ? n.markedRead(DateTime.now()) : n,
    ];
    return notifications.firstWhere((n) => n.id == id);
  }

  @override
  Future<void> markAllNotificationsRead() async {
    markAllReadCalls++;
    notifications = [
      for (final n in notifications) n.markedRead(DateTime.now()),
    ];
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
  Future<List<PaymentInfo>> getMyPayments(int userId) async => [verifyResult];

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
      status: booking.status == BookingStatus.confirmed
          ? BookingStatus.refundPending
          : BookingStatus.cancelled,
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
    final orderCode = booking.id * 1000000 + 195614;
    orderCodes[orderCode] = booking.id;
    return PayOsCheckout(
      paymentId: 501,
      orderCode: orderCode,
      checkoutUrl: checkoutUrl,
    );
  }

  @override
  Future<PaymentInfo> verifyPayOsPayment(int orderCodeOrBookingId) async {
    verifiedIds.add(orderCodeOrBookingId);
    final bookingId = orderCodes[orderCodeOrBookingId] ?? orderCodeOrBookingId;
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
    return PaymentInfo(
      id: verifyResult.id,
      paymentCode: verifyResult.paymentCode,
      bookingId: bookingId,
      amount: verifyResult.amount,
      status: verifyResult.status,
      method: verifyResult.method,
      transactionRef: verifyResult.transactionRef,
      createdAt: verifyResult.createdAt,
    );
  }

  @override
  Future<Refund?> getRefund(int paymentId) async => refund;

  @override
  Future<List<AppNotification>> getMyNotifications(int userId) async {
    return notifications;
  }

  @override
  Future<AppNotification> getNotification(int id) async =>
      notifications.firstWhere(
        (notification) => notification.id == id,
        orElse: () => throw const ApiException(
          statusCode: 404,
          message: 'Notification not found.',
        ),
      );
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
