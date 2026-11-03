import 'dart:async';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/session/session_state.dart';
import 'package:cinema_fe/data/models/app_notification.dart';
import 'package:cinema_fe/features/notification/widgets/notification_updates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

final added = AppNotification(
  id: 991,
  subject: 'A new cinema update',
  type: 'UPDATE',
  content: 'New notification delivered while this page was open.',
  status: 'SENT',
  createdAt: DateTime(2026, 11, 4),
);

class CountingBookings extends FakeBookingRepository {
  CountingBookings({super.notifications});
  int counts = 0;
  int lists = 0;
  bool offline = false;
  Completer<int>? pendingCount;
  @override
  Future<int> getUnreadNotificationCount() async {
    counts++;
    if (pendingCount != null) return pendingCount!.future;
    if (offline) throw StateError('offline');
    return super.getUnreadNotificationCount();
  }

  @override
  Future<List<AppNotification>> getMyNotifications(int userId) async {
    lists++;
    if (offline) throw StateError('offline');
    return super.getMyNotifications(userId);
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'Badge refreshes away from Home; sign-out stops requests and rejects late responses',
    (tester) async {
      final session = SessionState();
      final repository = CountingBookings(notifications: []);
      await tester.pumpWidget(
        buildTestApp(
          session: session,
          authenticated: true,
          bookingRepository: repository,
          initialRoute: AppRoutes.profile,
        ),
      );
      await pumpRoute(tester);
      expect(session.unreadNotifications, 0);
      repository.notifications = [added];
      await tester.pump(NotificationUpdates.interval);
      await pumpRoute(tester);
      expect(session.unreadNotifications, 1);
      repository.pendingCount = Completer<int>();
      await tester.pump(NotificationUpdates.interval);
      final calls = repository.counts;
      await tester.pump(const Duration(seconds: 15));
      expect(repository.counts, calls); // one request at a time
      session.clear();
      await pumpRoute(tester);
      repository.pendingCount!.complete(100);
      await pumpRoute(tester);
      await tester.pump(const Duration(seconds: 15));
      expect(session.unreadNotifications, 0);
      expect(repository.counts, calls);
    },
  );

  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'At $width new, read and deleted notifications sync without navigation or loading flashes',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final session = SessionState();
        final repository = CountingBookings(notifications: []);
        await tester.pumpWidget(
          buildTestApp(
            session: session,
            authenticated: true,
            bookingRepository: repository,
            initialRoute: AppRoutes.notifications,
          ),
        );
        await pumpRoute(tester);
        expect(find.text('You’re all caught up'), findsOneWidget);
        repository.notifications = [added];
        await tester.pump(NotificationUpdates.interval);
        await pumpRoute(tester);
        expect(find.text('A new cinema update'), findsOneWidget);
        expect(session.unreadNotifications, 1);
        expect(find.text('Loading notifications...'), findsNothing);
        repository.notifications = [added.markedRead(DateTime.now())];
        await tester.pump(NotificationUpdates.interval);
        await pumpRoute(tester);
        expect(session.unreadNotifications, 0);
        expect(find.text('A new cinema update'), findsOneWidget);
        repository.offline = true;
        await tester.pump(NotificationUpdates.interval);
        await pumpRoute(tester);
        expect(find.text('A new cinema update'), findsOneWidget);
        expect(find.text('Unable to load notifications'), findsNothing);
        repository.offline = false;
        repository.notifications = [];
        await tester.pump(NotificationUpdates.interval);
        await pumpRoute(tester);
        expect(find.text('A new cinema update'), findsNothing);
        expect(find.text('You’re all caught up'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Background pauses polling and resume immediately refreshes it', (
    tester,
  ) async {
    final session = SessionState();
    final repository = CountingBookings(notifications: []);
    await tester.pumpWidget(
      buildTestApp(
        session: session,
        authenticated: true,
        bookingRepository: repository,
      ),
    );
    await pumpRoute(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    final calls = repository.counts;
    repository.notifications = [added];
    await tester.pump(const Duration(seconds: 20));
    expect(repository.counts, calls);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpRoute(tester);
    expect(session.unreadNotifications, 1);
  });

  testWidgets('Guests never poll; signing in starts refreshing automatically', (
    tester,
  ) async {
    final session = SessionState();
    final repository = CountingBookings(notifications: [added]);
    await tester.pumpWidget(
      buildTestApp(session: session, bookingRepository: repository),
    );
    await pumpRoute(tester);
    await tester.pump(const Duration(seconds: 15));
    expect(repository.counts, 0);
    session.setAuthenticated(customerUser);
    await pumpRoute(tester);
    expect(repository.counts, greaterThan(0));
    expect(session.unreadNotifications, 1);
  });
}
