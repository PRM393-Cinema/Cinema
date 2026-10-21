import 'package:flutter/material.dart';

import '../core/session/session_state.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/booking_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/services/staff_service.dart';
import '../features/payment/payment_args.dart';
import 'customer_frame.dart';
import 'routes/app_router.dart';
import 'routes/app_routes.dart';
import 'session_app.dart';

// Customer app, on the web and on phones. Staff and admins use the admin
// website instead (lib/main_admin.dart).
class CinemaApp extends StatefulWidget {
  const CinemaApp({
    required this.authRepository,
    required this.catalogRepository,
    required this.bookingRepository,
    this.staffService,
    this.initialRoute,
    this.paymentReturn,
    super.key,
  });

  final AuthRepository authRepository;
  final CatalogRepository catalogRepository;
  final BookingRepository bookingRepository;

  // Lets staff accounts check tickets in from the app.
  final StaffService? staffService;
  final String? initialRoute;

  // Set when PayOS redirected the browser back to the web app.
  final PayOsReturn? paymentReturn;

  @override
  State<CinemaApp> createState() => _CinemaAppState();
}

class _CinemaAppState extends State<CinemaApp> {
  final _routes = RouteTracker();

  @override
  void dispose() {
    _routes.current.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = AppRouter(
      authRepository: widget.authRepository,
      catalogRepository: widget.catalogRepository,
      bookingRepository: widget.bookingRepository,
      staffService: widget.staffService,
      session: SessionProvider.of(context),
    );
    final payOsReturn = widget.paymentReturn;

    return SessionApp(
      title: 'CosmoQ Cinema',
      initialRoute: widget.initialRoute,
      navigatorObservers: [_routes],
      builder: (context, child) =>
          CustomerFrame(routes: _routes, child: child ?? const SizedBox()),
      onGenerateRoute: router.onGenerateRoute,
      onGenerateInitialRoutes: (name) => router.onGenerateInitialRoutes(
        payOsReturn == null
            ? name
            : AppRoutes.paymentResult(payOsReturn.orderCode),
      ),
    );
  }
}
