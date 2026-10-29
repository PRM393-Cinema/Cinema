import 'package:flutter/material.dart';

import '../app/routes/app_routes.dart';
import '../core/session/roles.dart';
import '../core/session/session_state.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/services/staff_service.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/admin/screens/admin_movies_screen.dart';
import '../features/admin/screens/admin_rooms_screen.dart';
import '../features/admin/screens/admin_users_screen.dart';
import '../features/admin/screens/staff_only_screen.dart';
import '../features/admin/widgets/admin_page.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/auth/screens/verify_email_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/staff/screens/staff_check_in_screen.dart';
import '../features/staff/screens/staff_counter_checkout_screen.dart';
import '../features/staff/screens/staff_create_booking_screen.dart';
import '../features/staff/screens/staff_dashboard_screen.dart';
import '../features/staff/screens/staff_notification_screen.dart';
import '../features/staff/screens/staff_operations_screen.dart';
import '../features/staff/screens/staff_record_screen.dart';
import '../features/staff/screens/staff_showtime_editor_screen.dart';
import '../features/admin/screens/admin_snacks_screen.dart';
import '../features/admin/screens/admin_promotions_screen.dart';
import '../features/admin/screens/admin_members_screen.dart';

enum _Access { public, staff, admin }

// Routes of the admin website (lib/main_admin.dart). Pages need a staff or
// admin account; movies, rooms and accounts need an admin one. Names are the
// URL (#/admin/movies), so a refresh or a shared link opens the same page.
class AdminRouter {
  AdminRouter({
    required this.authRepository,
    required this.catalogRepository,
    required this.staffService,
    required this.session,
  });

  final AuthRepository authRepository;
  final CatalogRepository catalogRepository;
  final StaffService staffService;
  final SessionState session;

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final match = _match(settings) ?? _landing();

    if (match.access != _Access.public && !session.isAuthenticated) {
      // Sign in, then continue to the requested page.
      return _page(
        RouteSettings(
          name: AppRoutes.login,
          arguments: <String, dynamic>{
            'pendingRoute': match.settings.name,
            'pendingArguments': match.settings.arguments,
          },
        ),
        _login,
      );
    }

    final roles = session.user?.roles;
    final allowed = switch (match.access) {
      _Access.public => true,
      _Access.staff => isManagementAccount(roles),
      _Access.admin => isAdminAccount(roles),
    };
    final target = allowed ? match : _landing();
    if (target.access == _Access.public) {
      return _page(target.settings, target.builder);
    }
    // Staff and admin pages sit next to the navigation.
    return _page(
      target.settings,
      (_) => AdminViewport(child: Builder(builder: target.builder)),
    );
  }

  // The navigation is on every page, so a page opened from its URL needs no
  // page underneath.
  List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) => [
    onGenerateRoute(RouteSettings(name: initialRoute)),
  ];

  Widget _login(BuildContext context) =>
      LoginScreen(authRepository: authRepository, allowRegister: false);

  _RouteMatch _landing() {
    final roles = session.user?.roles;
    if (isAdminAccount(roles)) {
      return _RouteMatch(
        const RouteSettings(name: AppRoutes.adminDashboard),
        (_) => AdminDashboardScreen(
          repository: authRepository,
          service: staffService,
        ),
        _Access.admin,
      );
    }
    if (isManagementAccount(roles)) {
      return _RouteMatch(
        const RouteSettings(name: AppRoutes.staffDashboard),
        (_) => StaffDashboardScreen(service: staffService),
        _Access.staff,
      );
    }
    if (session.isAuthenticated) {
      return _RouteMatch(
        const RouteSettings(name: AppRoutes.home),
        (_) => StaffOnlyScreen(authRepository: authRepository),
        _Access.public,
      );
    }
    return _RouteMatch(
      const RouteSettings(name: AppRoutes.login),
      _login,
      _Access.public,
    );
  }

  _RouteMatch? _match(RouteSettings settings) {
    final uri = Uri.tryParse(settings.name ?? AppRoutes.home);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
    final args = settings.arguments;

    final guestOnly = switch (uri.path) {
      AppRoutes.login || AppRoutes.verifyEmail => true,
      // Profile passes the signed-in email through the password change flow.
      AppRoutes.forgotPassword ||
      AppRoutes.resetPassword => args is! String || args != session.user?.email,
      _ => false,
    };
    if (session.isAuthenticated && guestOnly) return _landing();

    _RouteMatch staff(WidgetBuilder builder) =>
        _RouteMatch(settings, builder, _Access.staff);
    _RouteMatch admin(WidgetBuilder builder) =>
        _RouteMatch(settings, builder, _Access.admin);

    switch (uri.path) {
      case '/':
      case AppRoutes.home:
        return _landing();
      case AppRoutes.login:
        return _RouteMatch(settings, _login, _Access.public);
      case AppRoutes.verifyEmail:
        return _RouteMatch(
          settings,
          (_) => VerifyEmailScreen(authRepository: authRepository),
          _Access.public,
        );
      case AppRoutes.forgotPassword:
        return _RouteMatch(
          settings,
          (_) => ForgotPasswordScreen(authRepository: authRepository),
          _Access.public,
        );
      case AppRoutes.resetPassword:
        return _RouteMatch(
          settings,
          (_) => ResetPasswordScreen(authRepository: authRepository),
          _Access.public,
        );
      case AppRoutes.staffDashboard:
        return staff((_) => StaffDashboardScreen(service: staffService));
      case AppRoutes.staffOperations:
        return staff((_) => StaffOperationsScreen(service: staffService));
      case AppRoutes.staffCreateBooking:
        return staff(
          (_) => StaffCreateBookingScreen(
            service: staffService,
            catalog: catalogRepository,
          ),
        );
      case AppRoutes.staffCreateShowtime:
        return staff((_) => StaffShowtimeEditorScreen(service: staffService));
      case AppRoutes.staffCheckIn:
        return staff((_) => StaffCheckInScreen(service: staffService));
      case AppRoutes.staffProfile:
        return staff(
          (_) => ProfileScreen(authRepository: authRepository, staffMode: true),
        );
      case AppRoutes.adminDashboard:
        return admin(
          (_) => AdminDashboardScreen(
            repository: authRepository,
            service: staffService,
          ),
        );
      case AppRoutes.adminProfile:
        return admin(
          (_) => ProfileScreen(authRepository: authRepository, adminMode: true),
        );
      case AppRoutes.adminMovies:
        return admin((_) => AdminMoviesScreen(service: staffService));
      case AppRoutes.adminRooms:
        return admin((_) => AdminRoomsScreen(service: staffService));
      case AppRoutes.adminSnacks:
        return admin((_) => AdminSnacksScreen(service: staffService));
      case AppRoutes.adminPromotions:
        return admin((_) => AdminPromotionsScreen(service: staffService));
      case AppRoutes.adminMembers:
        return admin(
          (_) => AdminMembersScreen(
            repository: authRepository,
            service: staffService,
          ),
        );
      case AppRoutes.adminUsers:
        return admin((_) => AdminUsersScreen(repository: authRepository));
      case AppRoutes.adminCreateUser:
        return admin((_) => AdminCreateUserScreen(repository: authRepository));
    }

    final segments = uri.pathSegments;
    final id = segments.length >= 3 ? int.tryParse(segments[2]) : null;
    if (id == null || id <= 0) return null;

    if (segments[0] == 'staff') {
      if (segments.length == 4 &&
          segments[1] == 'showtimes' &&
          segments[3] == 'edit') {
        return staff(
          (_) => StaffShowtimeEditorScreen(service: staffService, id: id),
        );
      }
      if (segments.length == 4 &&
          segments[1] == 'bookings' &&
          segments[3] == 'notify') {
        return staff(
          (_) => StaffNotificationScreen(service: staffService, bookingId: id),
        );
      }
      if (segments.length == 4 &&
          segments[1] == 'bookings' &&
          segments[3] == 'checkout') {
        return staff(
          (_) =>
              StaffCounterCheckoutScreen(service: staffService, bookingId: id),
        );
      }
      if (segments.length == 3 &&
          const [
            'bookings',
            'showtimes',
            'rooms',
            'payments',
            'refunds',
          ].contains(segments[1])) {
        return staff(
          (_) => StaffRecordScreen(
            service: staffService,
            kind: segments[1],
            id: id,
          ),
        );
      }
    }
    if (segments.length == 3 &&
        segments[0] == 'admin' &&
        segments[1] == 'users') {
      return admin(
        (_) => AdminUserDetailScreen(repository: authRepository, userId: id),
      );
    }
    return null;
  }

  // Pages switch in place like a website, without the phone slide.
  Route<dynamic> _page(RouteSettings settings, WidgetBuilder builder) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      pageBuilder: (context, _, _) => builder(context),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }
}

class _RouteMatch {
  const _RouteMatch(this.settings, this.builder, this.access);

  final RouteSettings settings;
  final WidgetBuilder builder;
  final _Access access;
}
