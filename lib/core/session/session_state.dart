import 'package:flutter/widgets.dart';

import '../../data/models/auth_response.dart';

class SessionState extends ChangeNotifier {
  bool _isGuest = false;
  bool _isAuthenticated = false;
  AuthUser? _user;

  bool get isGuest => _isGuest;
  bool get isAuthenticated => _isAuthenticated;

  // The signed-in user, saved at login and refreshed with /auth/me.
  AuthUser? get user => _user;

  void setGuest() {
    _isGuest = true;
    _isAuthenticated = false;
    _user = null;
    notifyListeners();
  }

  void setAuthenticated([AuthUser? user]) {
    _isGuest = false;
    _isAuthenticated = true;
    _user = user ?? _user;
    notifyListeners();
  }

  void clear() {
    _isGuest = false;
    _isAuthenticated = false;
    _user = null;
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
