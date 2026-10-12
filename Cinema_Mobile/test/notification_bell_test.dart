import 'package:cinema_fe/core/session/session_state.dart';
import 'package:cinema_fe/data/models/app_notification.dart';
import 'package:cinema_fe/data/storage/notification_seen_storage.dart';
import 'package:cinema_fe/features/notification/widgets/notification_bell.dart';
import 'package:cinema_fe/features/notification/screens/notification_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';

AppNotification _notification(int id) => AppNotification(
  id: id,
  subject: 'Booking confirmed',
  type: 'BOOKING_CONFIRMED',
  content: 'Booking confirmed',
  status: 'SENT',
  createdAt: DateTime(2026, 10, 11),
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'Open notification list receives updates without reload and keeps data on errors',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final session = SessionState()..setAuthenticated(customerUser);
      final repository = _UpdatingNotifications();
      await tester.pumpWidget(
        SessionProvider(
          sessionState: session,
          child: MaterialApp(
            home: NotificationListScreen(bookingRepository: repository),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('You’re all caught up'), findsOneWidget);
      repository.notifications = [_notification(5)];
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('1 notifications'), findsOneWidget);
      expect(await NotificationSeenStorage().read(customerUser.userId), 5);
      repository.fail = true;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('1 notifications'), findsOneWidget);
      final calls = repository.calls;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect(repository.calls, calls);
      repository.fail = false;
      repository.notifications = [_notification(6), _notification(5)];
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('2 notifications'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Opening the loaded notification list clears the bell on return',
    (tester) async {
      final session = SessionState()..setAuthenticated(customerUser);
      final repository = FakeBookingRepository(
        notifications: [_notification(8)],
      );
      await tester.pumpWidget(
        SessionProvider(
          sessionState: session,
          child: MaterialApp(
            routes: {
              '/notifications': (_) =>
                  NotificationListScreen(bookingRepository: repository),
            },
            home: Scaffold(
              appBar: AppBar(
                actions: [NotificationBell(repository: repository)],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('notificationBadge')))
            .isLabelVisible,
        isTrue,
      );
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(await NotificationSeenStorage().read(customerUser.userId), 8);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('notificationBadge')))
            .isLabelVisible,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Bell detects new notifications and remembers viewed IDs per account',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final session = SessionState()..setAuthenticated(customerUser);
      final repository = FakeBookingRepository(notifications: []);
      final seen = NotificationSeenStorage();
      await tester.pumpWidget(
        SessionProvider(
          sessionState: session,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: [NotificationBell(repository: repository)],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Badge badge() =>
          tester.widget<Badge>(find.byKey(const Key('notificationBadge')));
      expect(badge().isLabelVisible, isFalse);
      repository.notifications = [_notification(4)];
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(badge().isLabelVisible, isTrue);
      expect(find.byTooltip('Notifications'), findsOneWidget);
      await seen.markSeen(customerUser.userId, 4);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(badge().isLabelVisible, isFalse);
      await seen.markSeen(customerUser.userId, 2);
      expect(await seen.read(customerUser.userId), 4);
      expect(await seen.read(customerUser.userId + 1), 0);
      repository.notifications = [_notification(5), _notification(4)];
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(badge().isLabelVisible, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

class _UpdatingNotifications extends FakeBookingRepository {
  _UpdatingNotifications() : super(notifications: []);
  bool fail = false;
  int calls = 0;

  @override
  Future<List<AppNotification>> getMyNotifications(int userId) async {
    calls++;
    if (fail) throw StateError('Network unavailable');
    return super.getMyNotifications(userId);
  }
}
