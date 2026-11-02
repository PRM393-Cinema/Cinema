import 'package:flutter/material.dart';

import '../core/session/session_state.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/booking_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/services/staff_service.dart';
import '../data/services/chat_service.dart';
import '../core/network/api_client.dart';
import '../features/chat/widgets/chat_launcher.dart';
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
    this.chatService,
    this.initialRoute,
    this.paymentReturn,
    super.key,
  });

  final AuthRepository authRepository;
  final CatalogRepository catalogRepository;
  final BookingRepository bookingRepository;

  // Lets staff accounts check tickets in from the app.
  final StaffService? staffService;
  final ChatService? chatService;
  final String? initialRoute;

  // Set when PayOS redirected the browser back to the web app.
  final PayOsReturn? paymentReturn;

  @override
  State<CinemaApp> createState() => _CinemaAppState();
}

class _CinemaAppState extends State<CinemaApp> {
  final _routes = RouteTracker();
  late final _chatService =
      widget.chatService ??
      ChatService(client: ApiClient(timeout: const Duration(seconds: 35)));
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    _signingOut = true;
    try {
      await widget.authRepository.logout();
      if (!mounted) return;
      SessionProvider.of(context).clear();
      _routes.navigator?.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } catch (_) {
      final overlay = _routes.navigator?.overlay;
      if (mounted && overlay != null) {
        ScaffoldMessenger.of(overlay.context).showSnackBar(
          const SnackBar(
            content: Text('Unable to sign out. Please try again.'),
          ),
        );
      }
    } finally {
      _signingOut = false;
    }
  }

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
      builder: (context, child) => ChatLauncher(
        routes: _routes,
        service: _chatService,
        child: CustomerFrame(
          routes: _routes,
          onSignOut: _signOut,
          child: child ?? const SizedBox(),
        ),
      ),
      onGenerateRoute: router.onGenerateRoute,
      onGenerateInitialRoutes: (name) => router.onGenerateInitialRoutes(
        payOsReturn == null
            ? name
            : AppRoutes.paymentResult(payOsReturn.orderCode),
      ),
    );
  }
}
