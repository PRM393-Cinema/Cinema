import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/widgets/cinema_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('A root page has no Back button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CinemaPage(title: 'Root', child: SizedBox()),
      ),
    );
    expect(find.byTooltip('Back'), findsNothing);
  });

  for (final size in [const Size(375, 844), const Size(1440, 900)]) {
    testWidgets('Customer pages go back at ${size.width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final route in [
        AppRoutes.movieDetail(inception.id),
        AppRoutes.movieDetail(999),
        AppRoutes.seatSelection(showtimeFixture().id),
        AppRoutes.bookingDetail(101),
        AppRoutes.myBookings,
        AppRoutes.profile,
        AppRoutes.notifications,
        AppRoutes.notificationDetail(notificationFixture.id),
        AppRoutes.paymentHistory,
        AppRoutes.payment(101),
        AppRoutes.paymentResult(101),
      ]) {
        await tester.pumpWidget(
          buildTestApp(
            authenticated: true,
            initialRoute: route,
            bookingRepository: FakeBookingRepository(
              bookings: [bookingFixture()],
            ),
          ),
        );
        await pumpFrames(tester);
        await tester.pump();
        expect(find.byTooltip('Back'), findsOneWidget, reason: route);
        expect(tester.takeException(), isNull, reason: route);

        await tester.tap(find.byTooltip('Back'));
        await pumpFrames(tester);
        expect(find.text('Step Into CosmoQ Cinema'), findsOneWidget);
        expect(find.byTooltip('Back'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    });
  }

  testWidgets('Back from the summary preserves selected seats', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        initialRoute: AppRoutes.seatSelection(showtimeFixture().id),
      ),
    );
    await pumpRoute(tester);
    await tester.tap(find.text('3').first);
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await pumpRoute(tester);
    expect(find.text('Booking Summary'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await pumpRoute(tester);
    expect(find.text('Select Seats'), findsOneWidget);
    expect(find.textContaining('A3'), findsOneWidget);
  });
}
