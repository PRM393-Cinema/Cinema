import 'package:flutter/material.dart';

import '../../core/session/session_state.dart';
import '../../data/models/booking_draft.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/booking_repository.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/services/staff_service.dart';
import '../../core/widgets/cinema_page.dart';
import '../../core/widgets/error_state.dart';
import '../../features/staff/screens/staff_dashboard_screen.dart';
import '../../features/staff/screens/staff_operations_screen.dart';
import '../../features/staff/screens/staff_record_screen.dart';
import '../../features/staff/screens/staff_create_booking_screen.dart';
import '../../features/staff/screens/staff_showtime_editor_screen.dart';
import '../../features/staff/screens/staff_notification_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/admin/screens/admin_users_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
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
import '../../features/payment/screens/payment_history_screen.dart';
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
    this.staffService,
  });

  final AuthRepository authRepository;
  final CatalogRepository catalogRepository;
  final BookingRepository bookingRepository;
  final SessionState session;
  final StaffService? staffService;

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final match = _match(settings);
    if (match == null) {
      final landing = _landing();
      return _page(landing.settings, landing.builder);
    }

    if (match.signInRequired && !session.isAuthenticated) {
      // Opened from a URL while signed out: sign in, then continue there.
      return _page(
        RouteSettings(
          name: AppRoutes.login,
          arguments: <String, dynamic>{
            'pendingRoute': match.settings.name,
            'pendingArguments': match.settings.arguments,
          },
        ),
        (_) => LoginScreen(authRepository: authRepository),
      );
    }

    return _page(match.settings, match.builder);
  }

  // Home stays under a page opened from its URL, so its back button leads
  // home instead of leaving the app.
  List<Route<dynamic>> onGenerateInitialRoutes(
    String initialRoute, {
    bool isPaymentReturn = false,
  }) {
    final landing = _landing();
    final home = _page(landing.settings, landing.builder);
    final match = _match(RouteSettings(name: initialRoute));
    if (match == null ||
        match.settings.name == '/' ||
        match.settings.name == landing.settings.name ||
        Uri.tryParse(match.settings.name ?? '')?.path == AppRoutes.home ||
        (match.signInRequired &&
            !session.isAuthenticated &&
            !isPaymentReturn)) {
      return [home];
    }
    return [home, onGenerateRoute(RouteSettings(name: initialRoute))];
  }

  Widget _home(BuildContext context) =>
      HomeScreen(catalogRepository: catalogRepository);

  _RouteMatch _landing() => session.user?.roles.contains('ROLE_ADMIN') == true
      ? _RouteMatch(
          const RouteSettings(name: AppRoutes.adminDashboard),
          (_) => AdminDashboardScreen(repository: authRepository),
          signInRequired: true,
        )
      : session.user?.roles.contains('ROLE_STAFF') == true
      ? _staffMatch(
          const RouteSettings(name: AppRoutes.staffDashboard),
          (service) => StaffDashboardScreen(service: service),
        )
      : _RouteMatch(const RouteSettings(name: AppRoutes.home), _home);

  _RouteMatch _staffMatch(
    RouteSettings settings,
    Widget Function(StaffService) builder,
  ) => _RouteMatch(
    settings,
    (_) => staffService == null
        ? const CinemaPage(
            title: 'Staff workspace',
            child: ErrorState(
              title: 'Service unavailable',
              message: 'Staff service is not configured.',
            ),
          )
        : builder(staffService!),
    signInRequired: true,
  );

  _RouteMatch? _match(RouteSettings settings) {
    final uri = Uri.tryParse(settings.name ?? AppRoutes.home);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
    final args = settings.arguments;
    if (uri.path.startsWith('/staff/') &&
        session.isAuthenticated &&
        !(session.user?.roles.any(
              (role) => role == 'ROLE_STAFF' || role == 'ROLE_ADMIN',
            ) ??
            false)) {
      return _landing();
    }
    if (uri.path.startsWith('/admin/') &&
        session.isAuthenticated &&
        !(session.user?.roles.contains('ROLE_ADMIN') ?? false)) {
      return _landing();
    }

    final guestOnly = switch (uri.path) {
      AppRoutes.login || AppRoutes.register || AppRoutes.verifyEmail => true,
      // Account passes the signed-in email through the password change flow.
      AppRoutes.forgotPassword ||
      AppRoutes.resetPassword => args is! String || args != session.user?.email,
      _ => false,
    };
    if (session.isAuthenticated && guestOnly) {
      return _landing();
    }

    switch (uri.path) {
      case AppRoutes.staffDashboard:
        return _staffMatch(
          settings,
          (service) => StaffDashboardScreen(service: service),
        );
      case AppRoutes.staffOperations:
        return _staffMatch(
          settings,
          (service) => StaffOperationsScreen(service: service),
        );
      case AppRoutes.staffCreateBooking:
        return _staffMatch(
          settings,
          (service) => StaffCreateBookingScreen(
            service: service,
            catalog: catalogRepository,
          ),
        );
      case AppRoutes.staffCreateShowtime:
        return _staffMatch(
          settings,
          (service) => StaffShowtimeEditorScreen(service: service),
        );
      case AppRoutes.staffProfile:
        return _RouteMatch(
          settings,
          (_) => ProfileScreen(authRepository: authRepository, staffMode: true),
          signInRequired: true,
        );
      case AppRoutes.adminDashboard:
        return _RouteMatch(
          settings,
          (_) => AdminDashboardScreen(repository: authRepository),
          signInRequired: true,
        );
      case AppRoutes.adminProfile:
        return _RouteMatch(
          settings,
          (_) => ProfileScreen(authRepository: authRepository, adminMode: true),
          signInRequired: true,
        );
      case AppRoutes.adminUsers:
        return _RouteMatch(
          settings,
          (_) => AdminUsersScreen(repository: authRepository),
          signInRequired: true,
        );
      case AppRoutes.adminCreateUser:
        return _RouteMatch(
          settings,
          (_) => AdminCreateUserScreen(repository: authRepository),
          signInRequired: true,
        );
      case '/':
      case AppRoutes.home:
        return _landing();
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
      case AppRoutes.paymentHistory:
        return _RouteMatch(
          settings,
          (_) => PaymentHistoryScreen(bookingRepository: bookingRepository),
          signInRequired: true,
        );
      case AppRoutes.profile:
        return _RouteMatch(
          session.user?.roles.contains('ROLE_ADMIN') == true
              ? const RouteSettings(name: AppRoutes.adminProfile)
              : session.user?.roles.contains('ROLE_STAFF') == true
              ? const RouteSettings(name: AppRoutes.staffProfile)
              : settings,
          (_) => ProfileScreen(
            authRepository: authRepository,
            adminMode: session.user?.roles.contains('ROLE_ADMIN') == true,
            staffMode:
                session.user?.roles.contains('ROLE_ADMIN') != true &&
                session.user?.roles.contains('ROLE_STAFF') == true,
          ),
          signInRequired: true,
        );
    }

    final segments = uri.pathSegments;
    if (segments.length >= 3 && segments[0] == 'staff') {
      final id = int.tryParse(segments[2]);
      if (id == null || id <= 0) return null;
      if (segments.length == 4 &&
          segments[1] == 'showtimes' &&
          segments[3] == 'edit') {
        return _staffMatch(
          settings,
          (service) => StaffShowtimeEditorScreen(service: service, id: id),
        );
      }
      if (segments.length == 4 &&
          segments[1] == 'bookings' &&
          segments[3] == 'notify') {
        return _staffMatch(
          settings,
          (service) => StaffNotificationScreen(service: service, bookingId: id),
        );
      }
      if (segments.length == 3 &&
          [
            'bookings',
            'showtimes',
            'rooms',
            'payments',
            'refunds',
          ].contains(segments[1])) {
        return _staffMatch(
          settings,
          (service) =>
              StaffRecordScreen(service: service, kind: segments[1], id: id),
        );
      }
      return null;
    }
    if (segments.length == 3 &&
        segments[0] == 'admin' &&
        segments[1] == 'users') {
      final userId = int.tryParse(segments[2]);
      if (userId == null || userId <= 0) return null;
      return _RouteMatch(
        settings,
        (_) =>
            AdminUserDetailScreen(repository: authRepository, userId: userId),
        signInRequired: true,
      );
    }
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
        return _RouteMatch(
          settings,
          (_) => NotificationDetailScreen(
            bookingRepository: bookingRepository,
            notificationId: id,
          ),
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
