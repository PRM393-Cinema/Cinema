import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

// On web the URL is the route name. These tests open screens straight from
// a URL, as after a page refresh or from a shared link.
void main() {
  testWidgets('Movie page loads the movie from its URL and goes back home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(initialRoute: AppRoutes.movieDetail(inception.id)),
    );
    await pumpRoute(tester);

    expect(find.text('Showtimes'), findsOneWidget);
    expect(find.text(inception.title), findsWidgets);

    await tester.binding.handlePopRoute();
    await pumpRoute(tester);
    expect(find.text('Step Into CosmoQ Cinema'), findsOneWidget);
  });

  testWidgets('Unknown movie id shows movie not found', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(initialRoute: AppRoutes.movieDetail(999)),
    );
    await pumpRoute(tester);

    expect(find.text('Movie not found'), findsOneWidget);
  });

  testWidgets('Seat page loads the showtime and its movie from its URL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        initialRoute: AppRoutes.seatSelection(showtimeFixture().id),
      ),
    );
    await pumpRoute(tester);

    expect(find.text('Select Seats'), findsOneWidget);
    expect(find.text(inception.title), findsOneWidget);
  });

  testWidgets('A refreshed booking summary goes back to the seat map', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        initialRoute: AppRoutes.bookingSummary(showtimeFixture().id),
      ),
    );
    await pumpRoute(tester);

    expect(find.text('Select Seats'), findsOneWidget);
    expect(find.text('Booking Summary'), findsNothing);
  });

  testWidgets('Payment page loads the booking from its URL', (
    WidgetTester tester,
  ) async {
    final booking = bookingFixture();
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        bookingRepository: FakeBookingRepository(bookings: [booking]),
        initialRoute: AppRoutes.payment(booking.id),
      ),
    );
    await pumpFrames(tester);

    expect(find.text('Code: ${booking.bookingCode}'), findsOneWidget);
    expect(find.text('Pay with PayOS'), findsOneWidget);
  });

  testWidgets('Booking page loads the booking from its URL', (
    WidgetTester tester,
  ) async {
    final booking = bookingFixture();
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        bookingRepository: FakeBookingRepository(bookings: [booking]),
        initialRoute: AppRoutes.bookingDetail(booking.id),
      ),
    );
    await pumpRoute(tester);

    expect(find.textContaining(booking.bookingCode), findsOneWidget);
  });

  testWidgets('A refreshed notification loads its detail by ID', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        initialRoute: AppRoutes.notificationDetail(notificationFixture.id),
      ),
    );
    await pumpRoute(tester);

    expect(find.text('Notification'), findsOneWidget);
    expect(find.text(notificationFixture.subject), findsOneWidget);
  });

  testWidgets('Signed-out link opens Home; Tickets asks to sign in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.myBookings));
    await pumpRoute(tester);

    expect(find.text('Step Into CosmoQ Cinema'), findsOneWidget);
    await tester.tap(find.text('Tickets'));
    await pumpRoute(tester);
    expect(find.byKey(const Key('loginTitle')), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('loginEmailField')),
        matching: find.byType(TextFormField),
      ),
      'khachhang1@gmail.com',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('loginPasswordField')),
        matching: find.byType(TextFormField),
      ),
      '123456',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final signIn = find.byType(AppButton).first;
    await tester.ensureVisible(signIn);
    await tester.tap(signIn);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await pumpRoute(tester);

    expect(find.text('My Bookings'), findsOneWidget);
  });
}
