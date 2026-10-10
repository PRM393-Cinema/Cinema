// Screen addresses. On web they are shown in the URL (#/movies/7), so the
// screens of one record carry its id and can load it again after a refresh.
abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const home = '/home';
  static const adminUsers = '/admin/users';
  static const adminCreateUser = '/admin/users/new';
  static String adminUser(int id) => '/admin/users/$id';
  static const myBookings = '/bookings';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const paymentHistory = '/payments';

  static String movieDetail(int movieId) => '/movies/$movieId';

  static String seatSelection(int showtimeId) => '/showtimes/$showtimeId/seats';

  static String bookingSummary(int showtimeId) =>
      '/showtimes/$showtimeId/summary';

  static String bookingDetail(int bookingId) => '/bookings/$bookingId';

  static String payment(int bookingId) => '/bookings/$bookingId/payment';

  static String paymentResult(int bookingId) => '/bookings/$bookingId/result';

  static String notificationDetail(int notificationId) =>
      '/notifications/$notificationId';
}
