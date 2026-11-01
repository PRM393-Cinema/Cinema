import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/models/app_notification.dart';
import 'package:cinema_fe/core/session/session_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final width in [960.0, 1440.0]) {
    testWidgets('Account menu aligns and toggles closed at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(buildTestApp(authenticated: true));
      await pumpRoute(tester);
      final button = find.byKey(const Key('webHeaderAccount'));
      final box = tester.renderObject<RenderBox>(button);
      final anchorRight = box
          .localToGlobal(box.size.bottomRight(Offset.zero))
          .dx;
      await tester.tap(button);
      await pumpRoute(tester);
      final items = find.byType(PopupMenuItem<String>);
      expect(items, findsNWidgets(3));
      final surface = find
          .ancestor(of: items.first, matching: find.byType(Material))
          .first;
      expect(tester.getRect(surface).right, closeTo(anchorRight, 1));
      final first = tester.getRect(items.first);
      for (var i = 1; i < 3; i++) {
        final rect = tester.getRect(items.at(i));
        expect(rect.width, first.width);
        expect(rect.height, closeTo(first.height, 0.01));
        expect(rect.left, first.left);
      }
      await tester.tap(button);
      await pumpRoute(tester);
      expect(items, findsNothing);
      await tester.tap(button);
      await pumpRoute(tester);
      expect(items, findsNWidgets(3));
      await tester.tapAt(const Offset(10, 120));
      await pumpRoute(tester);
      expect(items, findsNothing);
      expect(find.byKey(const Key('homeScrollView')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [900.0, 1440.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'Ticket cards align with different seat counts at $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final seats = [for (var i = 1; i <= 20; i++) 'C$i'];
          await tester.pumpWidget(
            buildTestApp(
              authenticated: true,
              initialRoute: AppRoutes.myBookings,
              bookingRepository: FakeBookingRepository(
                bookings: [
                  bookingFixture(id: 101, seatLabels: const ['A1']),
                  bookingFixture(id: 102, seatLabels: seats),
                ],
              ),
            ),
          );
          await pumpRoute(tester);
          expect(
            tester.getSize(find.byKey(const ValueKey('bookingCard-101'))),
            tester.getSize(find.byKey(const ValueKey('bookingCard-102'))),
          );
          final links = find.text('View booking');
          expect(
            tester.getTopLeft(links.at(0)).dy,
            tester.getTopLeft(links.at(1)).dy,
          );
          final summary = find.byKey(const ValueKey('bookingSeats-102'));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: summary, matching: find.byType(RichText)).first,
          );
          expect(paragraph.maxLines, 2);
          expect(paragraph.overflow, TextOverflow.ellipsis);
          expect(paragraph.didExceedMaxLines, isTrue);
          expect(
            tester
                .getRect(find.byKey(const ValueKey('bookingCard-102')))
                .contains(tester.getRect(summary).bottomRight),
            isTrue,
          );
          expect(find.byTooltip(seats.join(', ')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Account dropdown dismisses with Escape and signs out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuthRepository();
    final session = SessionState();
    await tester.pumpWidget(
      buildTestApp(authenticated: true, authRepository: auth, session: session),
    );
    await pumpRoute(tester);
    await tester.tap(find.byKey(const Key('webHeaderAccount')));
    await pumpRoute(tester);
    expect(find.text('Payment history'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpRoute(tester);
    expect(find.text('Sign out'), findsNothing);
    expect(auth.logoutCalls, 0);
    await tester.tap(find.byKey(const Key('webHeaderAccount')));
    await pumpRoute(tester);
    await tester.tap(find.text('Sign out'));
    await pumpRoute(tester);
    expect(auth.logoutCalls, 1);
    expect(session.isAuthenticated, isFalse);
    expect(find.byKey(const Key('webHeaderSignIn')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets(
      'Notification cards stay equal with long text at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          buildTestApp(
            authenticated: true,
            initialRoute: AppRoutes.notifications,
            bookingRepository: FakeBookingRepository(
              notifications: [
                notificationFixture,
                AppNotification(
                  id: 2,
                  subject: List.filled(20, 'Long title').join(' '),
                  type: 'NEWS',
                  content:
                      '<p>${List.filled(60, 'Long preview').join(' ')}</p>',
                  status: 'SENT',
                  createdAt: DateTime.now(),
                ),
              ],
            ),
          ),
        );
        await pumpRoute(tester);
        expect(
          tester.getSize(find.byKey(const ValueKey('notificationCard-1'))),
          tester.getSize(find.byKey(const ValueKey('notificationCard-2'))),
        );
        final title = tester.widget<Text>(
          find.byKey(const ValueKey('notificationTitle-2')),
        );
        expect(title.maxLines, 2);
        expect(title.overflow, TextOverflow.ellipsis);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [900.0, 1440.0]) {
    testWidgets('Desktop ticket cards keep history at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          initialRoute: AppRoutes.myBookings,
          bookingRepository: FakeBookingRepository(
            bookings: [
              bookingFixture(code: 'FIRST'),
              bookingFixture(id: 102, code: 'SECOND'),
              bookingFixture(
                id: 103,
                code: 'PAST',
                status: BookingStatus.cancelled,
              ),
            ],
          ),
        ),
      );
      await pumpRoute(tester);
      final first = tester.getRect(find.text('Code: FIRST'));
      final second = tester.getRect(find.text('Code: SECOND'));
      expect(first.top, closeTo(second.top, 1));
      expect(first.right, lessThan(second.left));
      expect(find.text('View booking'), findsNWidgets(2));
      expect(find.text('2 active bookings · 1 past booking'), findsOneWidget);
      await tester.tap(find.text('History'));
      await pumpRoute(tester);
      expect(find.text('Code: PAST'), findsOneWidget);
      expect(find.text('Code: FIRST'), findsNothing);
      await tester.tap(find.text('View booking'));
      await pumpRoute(tester);
      expect(find.text('Booking Detail'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Desktop notification cards mark read and open details at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repository = FakeBookingRepository(
          notifications: [notificationFixture],
        );
        await tester.pumpWidget(
          buildTestApp(
            authenticated: true,
            initialRoute: AppRoutes.notifications,
            bookingRepository: repository,
          ),
        );
        await pumpRoute(tester);
        final title = find.byKey(const ValueKey('notificationTitle-1'));
        expect(find.byKey(const ValueKey('unread-1')), findsOneWidget);
        expect(tester.getSize(title).width, lessThan(300));
        await tester.tap(find.byKey(const Key('markAllRead')));
        await pumpRoute(tester);
        expect(repository.markAllReadCalls, 1);
        expect(find.byKey(const ValueKey('unread-1')), findsNothing);
        await tester.tap(title);
        await pumpRoute(tester);
        expect(find.byKey(const Key('viewBooking')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
