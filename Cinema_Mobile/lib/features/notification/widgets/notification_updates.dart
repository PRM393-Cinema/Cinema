import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/session/roles.dart';
import '../../../core/session/session_state.dart';
import '../../../data/repositories/booking_repository.dart';

class NotificationUpdates extends StatefulWidget {
  const NotificationUpdates({
    required this.repository,
    required this.child,
    super.key,
  });

  final BookingRepository repository;
  final Widget child;
  static const interval = Duration(seconds: 5);

  static int revisionOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_NotificationRevision>()
          ?.notifier
          ?.value ??
      0;

  @override
  State<NotificationUpdates> createState() => _NotificationUpdatesState();
}

class _NotificationUpdatesState extends State<NotificationUpdates>
    with WidgetsBindingObserver {
  final _revision = ValueNotifier(0);
  Timer? _timer;
  SessionState? _session;
  int? _userId;
  int _generation = 0;
  int? _runningGeneration;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionProvider.of(context);
    final userId =
        session.isAuthenticated && !isManagementAccount(session.user?.roles)
        ? session.user?.userId
        : null;
    if (_session == session && _userId == userId) return;
    _session = session;
    _userId = userId;
    _generation++;
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    if (!_foreground || _userId == null) return;
    // Defer the initial refresh: session listeners must not be notified during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
    // shortcut: near-real-time polling, replace with push when concurrent traffic warrants it.
    _timer = Timer.periodic(NotificationUpdates.interval, (_) => _refresh());
  }

  bool _isCurrent(int generation, int userId) =>
      mounted &&
      _foreground &&
      _generation == generation &&
      _session?.isAuthenticated == true &&
      _session?.user?.userId == userId;

  Future<void> _refresh() async {
    final userId = _userId;
    final generation = _generation;
    if (userId == null ||
        !_isCurrent(generation, userId) ||
        _runningGeneration == generation) {
      return;
    }
    _runningGeneration = generation;
    try {
      final count = await widget.repository.getUnreadNotificationCount();
      if (_isCurrent(generation, userId)) {
        _session!.setUnreadNotifications(count);
      }
    } on Object {
      // Keep the last known badge; a temporary network failure must not clear it.
    } finally {
      if (_runningGeneration == generation) _runningGeneration = null;
      if (_isCurrent(generation, userId)) _revision.value++;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    _generation++;
    _restart();
    if (_foreground) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _revision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _NotificationRevision(notifier: _revision, child: widget.child);
}

class _NotificationRevision extends InheritedNotifier<ValueNotifier<int>> {
  const _NotificationRevision({required super.notifier, required super.child});
}
