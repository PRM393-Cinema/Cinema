import 'package:flutter/widgets.dart';

class SessionState extends ChangeNotifier {
  bool _isGuest = false;
  bool _isAuthenticated = false;

  bool get isGuest => _isGuest;
  bool get isAuthenticated => _isAuthenticated;

  void setGuest() {
    _isGuest = true;
    _isAuthenticated = false;
    notifyListeners();
  }

  void setAuthenticated() {
    _isGuest = false;
    _isAuthenticated = true;
    notifyListeners();
  }

  void clear() {
    _isGuest = false;
    _isAuthenticated = false;
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
    final provider = context.dependOnInheritedWidgetOfExactType<SessionProvider>();
    if (provider == null) {
      throw StateError('No SessionProvider found in context');
    }
    return provider.notifier!;
  }
}
