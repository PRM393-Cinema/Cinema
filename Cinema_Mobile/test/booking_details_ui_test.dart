import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'Pending detail counts down the existing hold and blocks expired payment',
    (tester) async {
      final deadline = DateTime.now().add(const Duration(seconds: 4));
      final booking = bookingFixture(expiresAt: deadline);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: FakeBookingRepository(bookings: [booking]),
          initialRoute: AppRoutes.bookingDetail(booking.id),
        ),
      );
      await pumpRoute(tester);
      final timer = find.byKey(const Key('holdTimerText'));
      expect(timer, findsOneWidget);
      expect(find.text('Pay Now'), findsOneWidget);
      final before = tester.widget<Text>(timer).data;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<Text>(timer).data, isNot(before));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('Your seat hold has expired. Please book again.'),
        findsOneWidget,
      );
      expect(find.text('Pay Now'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );
  for (final status in [
    BookingStatus.confirmed,
    BookingStatus.cancelled,
    BookingStatus.expired,
  ]) {
    testWidgets('$status detail has no active countdown', (tester) async {
      final booking = bookingFixture(status: status, paymentId: 10);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: FakeBookingRepository(bookings: [booking]),
          initialRoute: AppRoutes.bookingDetail(booking.id),
        ),
      );
      await pumpRoute(tester);
      expect(find.byKey(const Key('holdTimerText')), findsNothing);
      expect(find.text('Pay Now'), findsNothing);
    });
  }
  for (final (width, scale) in [(320.0, 1.0), (412.0, 1.5)]) {
    testWidgets('Booking details fit $width at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 924);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final booking = bookingFixture(
        status: BookingStatus.cancelled,
        paymentId: 10,
        seatLabels: ['B1', 'B2', 'B3', 'B4', 'B5'],
      );
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: FakeBookingRepository(bookings: [booking]),
          initialRoute: AppRoutes.bookingDetail(booking.id),
        ),
      );
      await pumpRoute(tester);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text(booking.bookingCode), findsOneWidget);
      expect(find.text('B5'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      expect(find.text(formatVnd(booking.totalAmount)), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('Cancel & request refund'), findsNothing);
      expect(find.text('Pay Now'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
