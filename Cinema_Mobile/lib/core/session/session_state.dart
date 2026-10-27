import 'package:flutter/widgets.dart';

import '../../data/models/auth_response.dart';

class SessionState extends ChangeNotifier {
  bool _isGuest = false;
  bool _isAuthenticated = false;
  AuthUser? _user;
  String? _expirationMessage;
  int _unreadNotifications = 0;

  bool get isGuest => _isGuest;

  // Notifications not opened yet, for the badge on the bell.
  int get unreadNotifications => _unreadNotifications;

  void setUnreadNotifications(int count) {
    final value = count < 0 ? 0 : count;
    if (value == _unreadNotifications) return;
    _unreadNotifications = value;
    notifyListeners();
  }

  bool get isAuthenticated => _isAuthenticated;
  String? get expirationMessage => _expirationMessage;

  // The signed-in user, saved at login and refreshed with /auth/me.
  AuthUser? get user => _user;

  void setGuest() {
    _expirationMessage = null;
    _isGuest = true;
    _isAuthenticated = false;
    _user = null;
    _unreadNotifications = 0;
    notifyListeners();
  }

  void setAuthenticated([AuthUser? user]) {
    _expirationMessage = null;
    _isGuest = false;
    _isAuthenticated = true;
    _user = user ?? _user;
    notifyListeners();
  }

  void clear({String? message}) {
    if (message != null && !_isAuthenticated) return;
    _expirationMessage = message;
    _isGuest = false;
    _isAuthenticated = false;
    _user = null;
    _unreadNotifications = 0;
    notifyListeners();
  }
}

class SessionProvider extends InheritedNotifier<SessionState> {
  const SessionProvider({
    required SessionState sessionState,
    required super.child,
    super.key,
  }) : super(notifier: sessionState);

  static SessionState of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<SessionProvider>();
    if (provider == null) {
      throw StateError('No SessionProvider found in context');
    }
    return provider.notifier!;
  }
}
