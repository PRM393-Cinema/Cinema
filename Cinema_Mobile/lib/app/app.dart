import 'package:flutter/material.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/booking_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/auth/screens/verify_email_screen.dart';
import '../features/booking/screens/booking_detail_screen.dart';
import '../features/booking/screens/booking_summary_screen.dart';
import '../features/booking/screens/my_bookings_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/movie/screens/movie_detail_screen.dart';
import '../features/notification/screens/notification_detail_screen.dart';
import '../features/notification/screens/notification_list_screen.dart';
import '../features/payment/payment_args.dart';
import '../features/payment/screens/payment_result_screen.dart';
import '../features/payment/screens/payment_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/seat/screens/seat_selection_screen.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class CinemaApp extends StatelessWidget {
  const CinemaApp({
    required this.authRepository,
    required this.catalogRepository,
    required this.bookingRepository,
    this.initialRoute = AppRoutes.home,
    this.paymentReturn,
    super.key,
  });

  final AuthRepository authRepository;
  final CatalogRepository catalogRepository;
  final BookingRepository bookingRepository;
  final String initialRoute;

  // Set when PayOS redirected the browser back to the web app.
  final PayOsReturn? paymentReturn;

  Map<String, WidgetBuilder> get _routes => {
    AppRoutes.login: (_) => LoginScreen(authRepository: authRepository),
    AppRoutes.register: (_) => RegisterScreen(authRepository: authRepository),
    AppRoutes.verifyEmail: (_) =>
        VerifyEmailScreen(authRepository: authRepository),
    AppRoutes.forgotPassword: (_) =>
        ForgotPasswordScreen(authRepository: authRepository),
    AppRoutes.resetPassword: (_) =>
        ResetPasswordScreen(authRepository: authRepository),
    AppRoutes.home: (_) => HomeScreen(catalogRepository: catalogRepository),
    AppRoutes.movieDetail: (_) =>
        MovieDetailScreen(catalogRepository: catalogRepository),
    AppRoutes.seatSelection: (_) =>
        SeatSelectionScreen(catalogRepository: catalogRepository),
    AppRoutes.bookingSummary: (_) =>
        BookingSummaryScreen(bookingRepository: bookingRepository),
    AppRoutes.payment: (_) =>
        PaymentScreen(bookingRepository: bookingRepository),
    AppRoutes.paymentResult: (_) =>
        PaymentResultScreen(bookingRepository: bookingRepository),
    AppRoutes.myBookings: (_) =>
        MyBookingsScreen(bookingRepository: bookingRepository),
    AppRoutes.bookingDetail: (_) =>
        BookingDetailScreen(bookingRepository: bookingRepository),
    AppRoutes.notifications: (_) =>
        NotificationListScreen(bookingRepository: bookingRepository),
    AppRoutes.notificationDetail: (_) => const NotificationDetailScreen(),
    AppRoutes.profile: (_) => ProfileScreen(authRepository: authRepository),
  };

  @override
  Widget build(BuildContext context) {
    final routes = _routes;
    final payOsReturn = paymentReturn;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cinema App',
      theme: AppTheme.darkTheme,
      initialRoute: initialRoute,
      routes: routes,
      onGenerateInitialRoutes: payOsReturn == null
          ? null
          : (_) => [
              _route(routes, AppRoutes.home),
              _route(
                routes,
                AppRoutes.paymentResult,
                arguments: PaymentResultArgs(bookingId: payOsReturn.orderCode),
              ),
            ],
    );
  }

  Route<dynamic> _route(
    Map<String, WidgetBuilder> routes,
    String name, {
    Object? arguments,
  }) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: name, arguments: arguments),
      builder: routes[name]!,
    );
  }
}
