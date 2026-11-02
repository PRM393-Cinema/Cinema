import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/session/session_state.dart';
import '../core/utils/layout.dart';
import '../core/widgets/top_notice.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'theme/theme_switch.dart';
import 'theme/theme_transition.dart';

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
  ThemeMode _themeMode = ThemeMode.dark;
  bool _themeChanged = false;
  static const _storage = FlutterSecureStorage();
  Future<void> _savingTheme = Future.value();

  @override
  void initState() {
    super.initState();
    _restoreTheme();
  }

  Future<void> _restoreTheme() async {
    try {
      final saved = await _storage.read(key: 'appearance.theme');
      if (!mounted || _themeChanged || saved == null) return;
      setState(
        () => _themeMode = saved == 'light' ? ThemeMode.light : ThemeMode.dark,
      );
    } on Object {
      // Storage can be unavailable; changing the theme still works in memory.
    }
  }

  void _toggleTheme() {
    transitionTheme(
      _applyTheme,
      animate: !MediaQuery.disableAnimationsOf(context),
    );
  }

  void _applyTheme() {
    if (!mounted) return;
    _themeChanged = true;
    setState(
      () => _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light,
    );
    final value = _themeMode == ThemeMode.light ? 'light' : 'dark';
    _savingTheme = _savingTheme.then((_) async {
      try {
        await _storage.write(key: 'appearance.theme', value: value);
      } on Object {
        // Keep the current theme usable if persistence is unavailable.
      }
    });
  }

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
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      themeAnimationDuration:
          usesBrowserThemeTransition || MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 420),
      themeAnimationCurve: Curves.easeInOutCubic,
      initialRoute: widget.initialRoute,
      onGenerateRoute: widget.onGenerateRoute,
      onGenerateInitialRoutes: widget.onGenerateInitialRoutes,
      navigatorObservers: widget.navigatorObservers,
      builder: (context, child) => ThemeSettings(
        toggle: _toggleTheme,
        child: ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            scrollbars: isDesktopLayout(context),
          ),
          child:
              widget.builder?.call(context, child) ?? child ?? const SizedBox(),
        ),
      ),
    );
  }
}
