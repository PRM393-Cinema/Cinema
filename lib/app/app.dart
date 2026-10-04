import 'package:flutter/material.dart';

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
import '../features/payment/screens/payment_result_screen.dart';
import '../features/payment/screens/payment_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/seat/screens/seat_selection_screen.dart';
import '../features/showtime/screens/showtime_selection_screen.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class CinemaApp extends StatelessWidget {
  const CinemaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cinema App',
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.verifyEmail: (_) => const VerifyEmailScreen(),
        AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
        AppRoutes.resetPassword: (_) => const ResetPasswordScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.movieDetail: (_) => const MovieDetailScreen(),
        AppRoutes.showtime: (_) => const ShowtimeSelectionScreen(),
        AppRoutes.seatSelection: (_) => const SeatSelectionScreen(),
        AppRoutes.bookingSummary: (_) => const BookingSummaryScreen(),
        AppRoutes.payment: (_) => const PaymentScreen(),
        AppRoutes.paymentResult: (_) => const PaymentResultScreen(),
        AppRoutes.myBookings: (_) => const MyBookingsScreen(),
        AppRoutes.bookingDetail: (_) => const BookingDetailScreen(),
        AppRoutes.notifications: (_) => const NotificationListScreen(),
        AppRoutes.notificationDetail: (_) => const NotificationDetailScreen(),
        AppRoutes.profile: (_) => const ProfileScreen(),
      },
    );
  }
}
