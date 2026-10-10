import 'package:flutter/material.dart';

import '../core/session/session_state.dart';
import '../core/widgets/top_notice.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/booking_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/services/staff_service.dart';
import '../features/payment/payment_args.dart';
import 'routes/app_router.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

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
  final StaffService? staffService;
  final String? initialRoute;

  // Set when PayOS redirected the browser back to the web app.
  final PayOsReturn? paymentReturn;

  @override
  State<CinemaApp> createState() => _CinemaAppState();
}

class _CinemaAppState extends State<CinemaApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  String? _expirationMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final message = SessionProvider.of(context).expirationMessage;
    if (message == _expirationMessage) return;
    _expirationMessage = message;
    if (message == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (_) => false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final overlay = _navigatorKey.currentState?.overlay;
        if (overlay != null) showTopNotice(overlay, message);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = AppRouter(
      authRepository: widget.authRepository,
      catalogRepository: widget.catalogRepository,
      bookingRepository: widget.bookingRepository,
      session: SessionProvider.of(context),
      staffService: widget.staffService,
    );
    final payOsReturn = widget.paymentReturn;

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'CosmoQ Cinema',
      theme: AppTheme.darkTheme,
      initialRoute: widget.initialRoute,
      onGenerateRoute: router.onGenerateRoute,
      onGenerateInitialRoutes: (name) => router.onGenerateInitialRoutes(
        payOsReturn == null
            ? name
            : AppRoutes.paymentResult(payOsReturn.orderCode),
        isPaymentReturn: payOsReturn != null,
      ),
    );
  }
}
