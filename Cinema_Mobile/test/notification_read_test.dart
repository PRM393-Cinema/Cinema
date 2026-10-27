import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/data/models/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

final _reminder = AppNotification(
  id: 2,
  bookingId: 101,
  subject: 'Nhắc giờ chiếu: Inception BK-1',
  type: 'SHOWTIME_REMINDER',
  content: '<h2>Sắp tới giờ chiếu</h2>',
  status: 'SENT',
  createdAt: DateTime(2026, 10, 28, 17, 30),
);

final _read = notificationFixture.markedRead(DateTime(2026, 10, 6));

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('A notification is unread until it has a read time', () {
    final notification = AppNotification.fromJson({
      'id': 3,
      'subject': 'S',
      'type': 'BOOKING_CONFIRMED',
      'content': '',
      'status': 'SENT',
      'createdAt': '2026-10-28T10:00:00',
      'readAt': '2026-10-28T11:00:00',
    });
    expect(notification.isRead, isTrue);
    expect(_reminder.isRead, isFalse);
    expect(_reminder.markedRead(DateTime(2026, 10, 28)).isRead, isTrue);
  });

  testWidgets('The bell shows how many notifications are unread', (
    tester,
  ) async {
    final bookings = FakeBookingRepository(notifications: [_reminder, _read]);
    await tester.pumpWidget(
      buildTestApp(authenticated: true, bookingRepository: bookings),
    );
    await pumpRoute(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('unreadBadge')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Opening a notification marks it read; all can be read', (
    tester,
  ) async {
    final second = AppNotification(
      id: 3,
      bookingId: 102,
      subject: 'Nhắc giờ chiếu: Oppenheimer BK-2',
      type: 'SHOWTIME_REMINDER',
      content: '<p>Sắp tới giờ chiếu</p>',
      status: 'SENT',
      createdAt: DateTime(2026, 10, 28, 18),
    );
    final bookings = FakeBookingRepository(
      notifications: [_reminder, second, _read],
    );
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        bookingRepository: bookings,
        initialRoute: AppRoutes.notifications,
      ),
    );
    await pumpRoute(tester);

    expect(find.byKey(const ValueKey('unread-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-1')), findsNothing);
    expect(find.textContaining('2 unread'), findsOneWidget);

    await tester.tap(find.text(_reminder.subject));
    await pumpRoute(tester);
    expect(bookings.readNotificationIds, [2]);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await pumpRoute(tester);
    expect(find.byKey(const ValueKey('unread-2')), findsNothing);
    expect(find.textContaining('1 unread'), findsOneWidget);

    await tester.tap(find.byKey(const Key('markAllRead')));
    await pumpRoute(tester);
    expect(bookings.markAllReadCalls, 1);
    expect(find.byKey(const ValueKey('unread-3')), findsNothing);
    expect(find.byKey(const Key('markAllRead')), findsNothing);
  });
}
