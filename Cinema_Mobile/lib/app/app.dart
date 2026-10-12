import 'package:flutter/material.dart';

import '../core/session/session_state.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/booking_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../features/payment/payment_args.dart';
import 'routes/app_router.dart';
import 'routes/app_routes.dart';
import 'session_app.dart';

// Customer app, on the web and on phones. Staff and admins use the admin
// website instead (lib/main_admin.dart).
class CinemaApp extends StatelessWidget {
  const CinemaApp({
    required this.authRepository,
    required this.catalogRepository,
    required this.bookingRepository,
    this.initialRoute,
    this.paymentReturn,
    super.key,
  });

  final AuthRepository authRepository;
  final CatalogRepository catalogRepository;
  final BookingRepository bookingRepository;
  final String? initialRoute;

  // Set when PayOS redirected the browser back to the web app.
  final PayOsReturn? paymentReturn;

  @override
  Widget build(BuildContext context) {
    final router = AppRouter(
      authRepository: authRepository,
      catalogRepository: catalogRepository,
      bookingRepository: bookingRepository,
      session: SessionProvider.of(context),
    );
    final payOsReturn = paymentReturn;

    return SessionApp(
      title: 'CosmoQ Cinema',
      initialRoute: initialRoute,
      onGenerateRoute: router.onGenerateRoute,
      onGenerateInitialRoutes: (name) => router.onGenerateInitialRoutes(
        payOsReturn == null
            ? name
            : AppRoutes.paymentResult(payOsReturn.orderCode),
      ),
    );
  }
}
