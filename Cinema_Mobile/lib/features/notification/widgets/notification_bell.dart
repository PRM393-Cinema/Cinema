import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/session/session_state.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/storage/notification_seen_storage.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({required this.repository, super.key});
  final BookingRepository repository;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with WidgetsBindingObserver {
  final _seen = NotificationSeenStorage();
  Timer? _timer;
  int? _userId;
  bool _hasNew = false;
  bool _checking = false;
  bool _wasCurrent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (ModalRoute.of(context)?.isCurrent != true ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      _check();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = SessionProvider.of(context).user?.userId;
    final isCurrent = ModalRoute.of(context)?.isCurrent == true;
    final needsCheck = userId != _userId || (isCurrent && !_wasCurrent);
    _wasCurrent = isCurrent;
    if (_userId != userId) {
      _userId = userId;
      _hasNew = false;
    }
    if (!needsCheck || !isCurrent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      _check();
    }
  }

  Future<void> _check() async {
    final userId = _userId;
    if (_checking || userId == null) return;
    _checking = true;
    try {
      final notifications = await widget.repository.getMyNotifications(userId);
      final seenId = await _seen.read(userId);
      if (!mounted || userId != _userId) return;
      setState(() => _hasNew = notifications.any((item) => item.id > seenId));
    } on Object {
      // A background check must not hide an existing badge on a network error.
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: _hasNew ? 'New notifications' : null,
    child: IconButton(
      tooltip: 'Notifications',
      onPressed: () async {
        await Navigator.pushNamed(context, AppRoutes.notifications);
        if (mounted) await _check();
      },
      icon: Badge(
        key: const Key('notificationBadge'),
        isLabelVisible: _hasNew,
        backgroundColor: AppColors.error,
        child: Icon(
          _hasNew
              ? Icons.notifications_active_outlined
              : Icons.notifications_none_outlined,
        ),
      ),
    ),
  );
}
