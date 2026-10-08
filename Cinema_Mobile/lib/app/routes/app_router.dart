import 'package:flutter/material.dart';

import '../../core/session/session_state.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/booking_draft.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/booking_repository.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/verify_email_screen.dart';
import '../../features/booking/screens/booking_detail_screen.dart';
import '../../features/booking/screens/booking_summary_screen.dart';
import '../../features/booking/screens/my_bookings_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/movie/screens/movie_detail_screen.dart';
import '../../features/notification/screens/notification_detail_screen.dart';
import '../../features/notification/screens/notification_list_screen.dart';
import '../../features/payment/payment_args.dart';
import '../../features/payment/screens/payment_result_screen.dart';
import '../../features/payment/screens/payment_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/seat/screens/seat_selection_screen.dart';
import 'app_routes.dart';

// Builds screens from route names such as /movies/7. On web the name is the
// URL, so a refreshed page or a shared link opens the same screen: screens
// use the object passed by the previous screen and otherwise load it by id.
class AppRouter {
  AppRouter({
    required this.authRepository,
    required this.catalogRepository,
    required this.bookingRepository,
    required this.session,
  });

  final AuthRepository authRepository;
  final CatalogRepository catalogRepository;
  final BookingRepository bookingRepository;
  final SessionState session;

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final match = _match(settings);
    if (match == null) {
      return _page(const RouteSettings(name: AppRoutes.home), _home);
    }

    if (match.signInRequired && !session.isAuthenticated) {
      // Opened from a URL while signed out: sign in, then continue there.
      return _page(
        RouteSettings(
          name: AppRoutes.login,
          arguments: <String, dynamic>{
            'pendingRoute': settings.name,
            'pendingArguments': settings.arguments,
          },
        ),
        (_) => LoginScreen(authRepository: authRepository),
      );
    }

    return _page(match.settings, match.builder);
  }

  // Home stays under a page opened from its URL, so its back button leads
  // home instead of leaving the app.
  List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) {
    final home = _page(const RouteSettings(name: AppRoutes.home), _home);
    final path = Uri.parse(initialRoute).path;
    if (path == '/' || path == AppRoutes.home) {
      return [home];
    }
    return [home, onGenerateRoute(RouteSettings(name: initialRoute))];
  }

  Widget _home(BuildContext context) =>
      HomeScreen(catalogRepository: catalogRepository);

  _RouteMatch? _match(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? AppRoutes.home);
    final args = settings.arguments;

    switch (uri.path) {
      case '/':
      case AppRoutes.home:
        return _RouteMatch(settings, _home);
      case AppRoutes.login:
        return _RouteMatch(
          settings,
          (_) => LoginScreen(authRepository: authRepository),
        );
      case AppRoutes.register:
        return _RouteMatch(
          settings,
          (_) => RegisterScreen(authRepository: authRepository),
        );
      case AppRoutes.verifyEmail:
        return _RouteMatch(
          settings,
          (_) => VerifyEmailScreen(authRepository: authRepository),
        );
      case AppRoutes.forgotPassword:
        return _RouteMatch(
          settings,
          (_) => ForgotPasswordScreen(authRepository: authRepository),
        );
      case AppRoutes.resetPassword:
        return _RouteMatch(
          settings,
          (_) => ResetPasswordScreen(authRepository: authRepository),
        );
      case AppRoutes.myBookings:
        return _RouteMatch(
          settings,
          (_) => MyBookingsScreen(bookingRepository: bookingRepository),
          signInRequired: true,
        );
      case AppRoutes.notifications:
        return _notificationList();
      case AppRoutes.profile:
        return _RouteMatch(
          settings,
          (_) => ProfileScreen(authRepository: authRepository),
          signInRequired: true,
        );
    }

    final segments = uri.pathSegments;
    final id = segments.length > 1 ? int.tryParse(segments[1]) : null;
    if (id == null) return null;
    final page = segments.length == 3 ? segments[2] : null;

    switch (segments.first) {
      case 'movies' when segments.length == 2:
        return _RouteMatch(
          settings,
          (_) => MovieDetailScreen(
            catalogRepository: catalogRepository,
            movieId: id,
          ),
        );
      case 'showtimes' when page == 'seats' || page == 'summary':
        // The chosen seats only live in memory, so a refreshed summary goes
        // back to the seat map.
        if (page == 'summary' && args is BookingDraft) {
          return _RouteMatch(
            settings,
            (_) => BookingSummaryScreen(bookingRepository: bookingRepository),
            signInRequired: true,
          );
        }
        return _RouteMatch(
          RouteSettings(
            name: AppRoutes.seatSelection(id),
            arguments: args is SeatSelectionArgs ? args : null,
          ),
          (_) => SeatSelectionScreen(
            catalogRepository: catalogRepository,
            showtimeId: id,
          ),
          signInRequired: true,
        );
      case 'bookings' when segments.length == 2:
        return _RouteMatch(
          settings,
          (_) => BookingDetailScreen(
            bookingRepository: bookingRepository,
            bookingId: id,
          ),
          signInRequired: true,
        );
      case 'bookings' when page == 'payment':
        return _RouteMatch(
          settings,
          (_) => PaymentScreen(
            bookingRepository: bookingRepository,
            bookingId: id,
          ),
          signInRequired: true,
        );
      case 'bookings' when page == 'result':
        return _RouteMatch(
          RouteSettings(
            name: settings.name,
            arguments: args is PaymentResultArgs
                ? args
                : PaymentResultArgs(bookingId: id),
          ),
          (_) => PaymentResultScreen(bookingRepository: bookingRepository),
          signInRequired: true,
        );
      case 'notifications' when segments.length == 2:
        // There is no endpoint for a single notification: after a refresh
        // the list is shown instead.
        if (args is! AppNotification) return _notificationList();
        return _RouteMatch(
          settings,
          (_) => const NotificationDetailScreen(),
          signInRequired: true,
        );
    }
    return null;
  }

  _RouteMatch _notificationList() {
    return _RouteMatch(
      const RouteSettings(name: AppRoutes.notifications),
      (_) => NotificationListScreen(bookingRepository: bookingRepository),
      signInRequired: true,
    );
  }

  Route<dynamic> _page(RouteSettings settings, WidgetBuilder builder) {
    return MaterialPageRoute<dynamic>(settings: settings, builder: builder);
  }
}

class _RouteMatch {
  const _RouteMatch(this.settings, this.builder, {this.signInRequired = false});

  final RouteSettings settings;
  final WidgetBuilder builder;
  final bool signInRequired;
}
