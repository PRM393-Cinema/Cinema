import 'package:flutter/material.dart';

import '../core/session/session_state.dart';
import '../core/widgets/top_notice.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

// MaterialApp shared by the customer app and the admin website. When the
// session ends (expired, account locked, role changed) it opens Sign in and
// shows the reason at the top of the screen.
class SessionApp extends StatefulWidget {
  const SessionApp({
    required this.title,
    required this.onGenerateRoute,
    required this.onGenerateInitialRoutes,
    this.initialRoute,
    this.builder,
    this.navigatorObservers = const [],
    super.key,
  });

  final String title;
  final RouteFactory onGenerateRoute;
  final InitialRouteListFactory onGenerateInitialRoutes;
  final String? initialRoute;

  // Wraps every page, for example with the website navigation bar.
  final TransitionBuilder? builder;
  final List<NavigatorObserver> navigatorObservers;

  @override
  State<SessionApp> createState() => _SessionAppState();
}

class _SessionAppState extends State<SessionApp> {
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
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: widget.title,
      theme: AppTheme.darkTheme,
      initialRoute: widget.initialRoute,
      onGenerateRoute: widget.onGenerateRoute,
      onGenerateInitialRoutes: widget.onGenerateInitialRoutes,
      navigatorObservers: widget.navigatorObservers,
      builder: widget.builder,
    );
  }
}
