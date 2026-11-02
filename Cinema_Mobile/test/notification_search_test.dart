import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/data/models/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/test_app.dart';

List<AppNotification> _notifications() => [
  for (var index = 0; index < 13; index++)
    AppNotification(
      id: index + 1,
      subject: 'Booking update BK-SEARCH-$index',
      type: index == 0 ? 'REFUND_REQUESTED' : 'BOOKING_CONFIRMED',
      content:
          '<h2>${index == 0 ? 'Hoàn tiền' : 'Cập nhật vé $index'}</h2>'
          '<p>${index == 12 ? 'Ký ức &amp; ánh sáng' : 'Thông tin đặt vé'}</p>',
      status: 'SENT',
      createdAt: DateTime(2026, 11, 1),
    ),
];

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final width in [375.0, 1440.0]) {
    testWidgets(
      'Notification search filters all pages and preserves state at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repository = FakeBookingRepository(
          notifications: _notifications(),
        );
        await tester.pumpWidget(
          buildTestApp(
            authenticated: true,
            initialRoute: AppRoutes.notifications,
            bookingRepository: repository,
          ),
        );
        await pumpRoute(tester);
        await tester.ensureVisible(find.byKey(const Key('nextPage')));
        await pumpRoute(tester);
        await tester.tap(find.byKey(const Key('nextPage')));
        await pumpRoute(tester);
        expect(find.text('Page 2 of 2'), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, 5000));
        await pumpRoute(tester);
        final search = find.byKey(const Key('notificationSearch'));
        for (final (query, title) in [
          ('  bk-search-12  ', 'Cập nhật vé 12'),
          ('Ký ức & ánh sáng', 'Cập nhật vé 12'),
          ('HOÀN TIỀN', 'Hoàn tiền'),
          ('refund', 'Hoàn tiền'),
        ]) {
          await tester.enterText(search, query);
          await pumpRoute(tester);
          expect(find.text(title), findsOneWidget);
          expect(find.textContaining('1 of 13 notifications'), findsOneWidget);
          expect(find.text('Page 2 of 2'), findsNothing);
        }
        expect(repository.readNotificationIds, isEmpty);
        await tester.enterText(search, 'missing-message');
        await pumpRoute(tester);
        expect(find.text('No matching notifications'), findsOneWidget);
        await tester.tap(find.byKey(const Key('clearNotificationSearch')));
        await pumpRoute(tester);
        expect(find.text('Page 1 of 2'), findsOneWidget);
        expect(find.text('No matching notifications'), findsNothing);

        await tester.enterText(search, 'BK-SEARCH-12');
        await pumpRoute(tester);
        await tester.tap(find.byKey(const ValueKey('notificationTitle-13')));
        await pumpRoute(tester);
        expect(repository.readNotificationIds, [13]);
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await pumpRoute(tester);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller!
              .text,
          'BK-SEARCH-12',
        );
        expect(find.textContaining('1 of 13 notifications'), findsOneWidget);
        expect(find.byKey(const ValueKey('unread-13')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final light in [false, true]) {
    testWidgets(
      'Notification cards fit narrow web and large text: light=$light',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({
          'appearance.theme': light ? 'light' : 'dark',
        });
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final (size, scale) in [
          (const Size(900, 1000), 1.0),
          (const Size(320, 812), 2.0),
          (const Size(844, 375), 1.5),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pumpWidget(
            buildTestApp(
              authenticated: true,
              initialRoute: AppRoutes.notifications,
              bookingRepository: FakeBookingRepository(
                notifications: _notifications().take(2).toList(),
              ),
            ),
          );
          await pumpRoute(tester);
          expect(find.byKey(const Key('notificationSearch')), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      },
    );
  }
}
