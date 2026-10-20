import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_exception.dart';
import 'package:cinema_fe/core/session/session_state.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/core/widgets/app_button.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/models/payment.dart';
import 'package:cinema_fe/data/models/seat.dart';
import 'package:cinema_fe/features/payment/payment_args.dart';
import 'package:cinema_fe/features/seat/widgets/seat_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  late FakeUrlLauncher urlLauncher;

  setUp(() {
    urlLauncher = FakeUrlLauncher();
    UrlLauncherPlatform.instance = urlLauncher;
  });

  group('Seat selection and booking', () {
    testWidgets('Seat map fits a phone screen and stays centered', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Room 2 of the seed data: three rows of ten seats.
      final catalog = FakeCatalogRepository(
        seatMap: ShowtimeSeatsData.fromOccupied(
          seats: [
            for (final (index, row) in ['A', 'B', 'C'].indexed)
              for (var number = 1; number <= 10; number++)
                Seat(
                  id: index * 10 + number,
                  roomId: 1,
                  row: row,
                  number: number,
                  type: 'NORMAL',
                ),
          ],
          occupiedSeatIds: const [],
        ),
      );
      await _openSeatSelection(tester, catalogRepository: catalog);

      Rect seatRect(String number) => tester.getRect(
        find.ancestor(
          of: find.text(number).first,
          matching: find.byType(SeatItem),
        ),
      );
      final firstSeat = seatRect('1');
      final lastSeat = seatRect('10');
      final leftGap = firstSeat.left;
      final rightGap = 375 - lastSeat.right;

      expect(leftGap, greaterThan(0));
      expect(rightGap, greaterThan(0));
      expect((leftGap - rightGap).abs(), lessThan(2));

      // The last seat of the row is still tappable.
      await tester.tap(find.text('10').first);
      await tester.pump();
      expect(find.text('1 seat(s)'), findsOneWidget);
    });

    testWidgets('Seat map marks taken seats and updates the total', (
      WidgetTester tester,
    ) async {
      await _openSeatSelection(tester);

      expect(find.text('0 seat(s)'), findsOneWidget);
      final continueBtn = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).last,
      );
      expect(continueBtn.onPressed, isNull);

      // A1 is free.
      await tester.tap(find.text('1').first);
      await tester.pump();
      expect(find.text('1 seat(s)'), findsOneWidget);
      expect(find.text(formatVnd(90000)), findsOneWidget);

      // A2 is taken by another booking and cannot be selected.
      await tester.tap(find.text('2').first);
      await tester.pump();
      expect(find.text('1 seat(s)'), findsOneWidget);

      // Tap again to deselect A1.
      await tester.tap(find.text('1').first);
      await tester.pump();
      expect(find.text('0 seat(s)'), findsOneWidget);
    });

    testWidgets('A sweetbox is picked as a couple and shown in the back row', (
      WidgetTester tester,
    ) async {
      // Row A is a sweetbox row; B4 is taken.
      final catalog = FakeCatalogRepository(
        seatMap: ShowtimeSeatsData.fromOccupied(
          seats: [
            for (final (index, (row, type)) in [
              ('A', 'SWEETBOX'),
              ('B', 'VIP'),
            ].indexed)
              for (var number = 1; number <= 4; number++)
                Seat(
                  id: index * 4 + number,
                  roomId: 1,
                  row: row,
                  number: number,
                  type: type,
                ),
          ],
          occupiedSeatIds: const [8],
        ),
      );
      await _openSeatSelection(tester, catalogRepository: catalog);

      // Sweetbox row A sits behind row B, and every seat type has a key.
      expect(
        tester.getTopLeft(find.text('A').first).dy,
        greaterThan(tester.getTopLeft(find.text('B').first).dy),
      );
      for (final label in ['VIP', 'Sweetbox (couple)', 'Selected']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Standard'), findsNothing);

      Finder seat(String number, {required bool sweetbox}) =>
          (sweetbox ? find.text(number).last : find.text(number).first);

      // An odd seat brings the even one on its right, and back.
      await tester.tap(seat('1', sweetbox: true));
      await tester.pump();
      expect(find.text('2 seat(s)'), findsOneWidget);
      await tester.tap(seat('2', sweetbox: true));
      await tester.pump();
      expect(find.text('0 seat(s)'), findsOneWidget);

      // An even seat brings the odd one on its left.
      await tester.tap(seat('4', sweetbox: true));
      await tester.pump();
      expect(find.text('2 seat(s)'), findsOneWidget);
      expect(find.text(formatVnd(180000)), findsOneWidget);

      // A single VIP seat is picked on its own.
      await tester.tap(seat('1', sweetbox: false));
      await tester.pump();
      expect(find.text('3 seat(s)'), findsOneWidget);
    });

    testWidgets('A sweetbox whose pair is taken cannot be picked', (
      WidgetTester tester,
    ) async {
      final catalog = FakeCatalogRepository(
        seatMap: ShowtimeSeatsData.fromOccupied(
          seats: [
            for (var number = 1; number <= 4; number++)
              Seat(
                id: number,
                roomId: 1,
                row: 'A',
                number: number,
                type: 'SWEETBOX',
              ),
          ],
          occupiedSeatIds: const [4],
        ),
      );
      await _openSeatSelection(tester, catalogRepository: catalog);

      await tester.tap(find.text('3').first);
      await tester.pump();
      expect(find.text('0 seat(s)'), findsOneWidget);
      expect(
        find.text(
          'A3 is a sweetbox (couple seat) and A4 is taken, so it cannot be '
          'booked.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('VIP and sweetbox seats cost more', (
      WidgetTester tester,
    ) async {
      // Row A is a sweetbox row, row B a VIP row.
      final catalog = FakeCatalogRepository(
        showtimes: [
          showtimeFixture(
            seatPrices: const {
              'NORMAL': 90000,
              'VIP': 108000,
              'SWEETBOX': 117000,
            },
          ),
        ],
        seatMap: ShowtimeSeatsData.fromOccupied(
          seats: [
            for (final (index, (row, type)) in [
              ('A', 'SWEETBOX'),
              ('B', 'VIP'),
            ].indexed)
              for (var number = 1; number <= 4; number++)
                Seat(
                  id: index * 4 + number,
                  roomId: 1,
                  row: row,
                  number: number,
                  type: type,
                ),
          ],
          occupiedSeatIds: const [],
        ),
      );
      await _openSeatSelection(tester, catalogRepository: catalog);

      // The room has no standard seats: its cheapest seat is a VIP one.
      expect(
        find.text('Room 1 • from ${formatVnd(108000)} / seat'),
        findsOneWidget,
      );
      expect(find.text(formatVnd(108000)), findsOneWidget);
      expect(find.text('${formatVnd(234000)} / pair'), findsOneWidget);

      // A sweetbox (A1 and A2) and a VIP seat (B1).
      await tester.tap(find.text('1').last);
      await tester.tap(find.text('1').first);
      await tester.pump();
      expect(find.text('3 seat(s)'), findsOneWidget);
      expect(find.text(formatVnd(342000)), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await pumpRoute(tester);
      expect(find.text('1x VIP (${formatVnd(108000)})'), findsOneWidget);
      expect(find.text('2x Sweetbox (${formatVnd(117000)})'), findsOneWidget);
      expect(find.text(formatVnd(234000)), findsOneWidget);
      expect(find.text(formatVnd(342000)), findsOneWidget);
    });

    testWidgets('The key of a map wider than the phone stays on screen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Rows of 14 seats are wider than the phone, so the map is panned.
      final catalog = FakeCatalogRepository(
        showtimes: [
          showtimeFixture(
            seatPrices: const {
              'NORMAL': 90000,
              'VIP': 108000,
              'SWEETBOX': 117000,
            },
          ),
        ],
        seatMap: ShowtimeSeatsData.fromOccupied(
          seats: [
            for (final (index, (row, type)) in [
              ('A', 'NORMAL'),
              ('B', 'VIP'),
              ('C', 'SWEETBOX'),
            ].indexed)
              for (var number = 1; number <= 14; number++)
                Seat(
                  id: index * 14 + number,
                  roomId: 1,
                  row: row,
                  number: number,
                  type: type,
                ),
          ],
          occupiedSeatIds: const [],
        ),
      );
      await _openSeatSelection(tester, catalogRepository: catalog);

      for (final label in [
        'Standard',
        'VIP',
        'Sweetbox (couple)',
        '${formatVnd(234000)} / pair',
        'Selected',
        'Unavailable',
      ]) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(375), reason: label);
      }
    });

    testWidgets('Seats taken by others while choosing are let go', (
      WidgetTester tester,
    ) async {
      final catalog = FakeCatalogRepository();
      await _openSeatSelection(tester, catalogRepository: catalog);

      // B1 and B2 (ids 5 and 6).
      await tester.tap(find.text('1').last);
      await tester.tap(find.text('2').last);
      await tester.pump();
      expect(find.text('2 seat(s)'), findsOneWidget);

      // Another customer takes B1; the open map shows it within seconds.
      catalog.seatMap = ShowtimeSeatsData.fromOccupied(
        seats: seatMapFixture.seats,
        occupiedSeatIds: const [2, 5],
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(catalog.seatMapLoads, 2);
      expect(find.text('1 seat(s)'), findsOneWidget);
      expect(
        find.text('B1 was just taken, so it was removed from your seats.'),
        findsOneWidget,
      );

      // No refresh behind the booking summary.
      await tester.tap(find.text('Continue'));
      await pumpRoute(tester);
      await tester.pump(const Duration(seconds: 20));
      expect(catalog.seatMapLoads, 2);
    });

    testWidgets('Confirm Booking creates the booking and opens payment', (
      WidgetTester tester,
    ) async {
      final bookings = FakeBookingRepository();
      await _openSeatSelection(tester, bookingRepository: bookings);

      // B1 and B2 (ids 5 and 6).
      await tester.tap(find.text('1').last);
      await tester.tap(find.text('2').last);
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await pumpRoute(tester);

      expect(find.text('Booking Summary'), findsWidgets);
      expect(find.text('B1, B2'), findsOneWidget);
      expect(find.text('2 Ticket(s)'), findsOneWidget);
      expect(find.text(formatVnd(180000)), findsWidgets);

      await tester.tap(find.text('Confirm Booking'));
      await pumpFrames(tester);

      expect(bookings.createCalls, hasLength(1));
      expect(bookings.createCalls.single.showtimeId, 11);
      expect(bookings.createCalls.single.seatIds, [5, 6]);

      expect(find.text('Pay with PayOS'), findsOneWidget);
      expect(find.textContaining('Seats held for'), findsOneWidget);
    });

    testWidgets('Seats taken meanwhile send the customer back to choose', (
      WidgetTester tester,
    ) async {
      final catalog = FakeCatalogRepository();
      final bookings = FakeBookingRepository(
        createError: const ApiException(
          statusCode: 409,
          message: 'Seat B1 is no longer available.',
        ),
      );
      await _openSeatSelection(
        tester,
        catalogRepository: catalog,
        bookingRepository: bookings,
      );

      await tester.tap(find.text('1').last);
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await pumpRoute(tester);
      await tester.tap(find.text('Confirm Booking'));
      await pumpRoute(tester);

      expect(find.text('Seats no longer available'), findsOneWidget);

      // Another customer now holds B1.
      catalog.seatMap = ShowtimeSeatsData.fromOccupied(
        seats: seatMapFixture.seats,
        occupiedSeatIds: const [2, 5],
      );
      await tester.tap(find.text('Choose again'));
      await pumpRoute(tester);

      expect(find.text('Booking Summary'), findsNothing);
      expect(find.text('0 seat(s)'), findsOneWidget);
      expect(catalog.seatMapLoads, 2);
    });
  });

  group('PayOS payment', () {
    testWidgets('Pay with PayOS opens the checkout link', (
      WidgetTester tester,
    ) async {
      final bookings = FakeBookingRepository(
        bookings: [bookingFixture(id: 101)],
      );
      await _openPaymentFromMyBookings(tester, bookings);

      await tester.tap(find.text('Pay with PayOS'));
      await pumpFrames(tester);

      expect(bookings.checkoutBookingIds, [101]);
      expect(urlLauncher.launchedUrls, ['https://pay.payos.vn/web/test-link']);
      expect(
        find.textContaining('Complete the payment on the PayOS page'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Coming back from PayOS confirms the booking and shows success',
      (WidgetTester tester) async {
        final bookings = FakeBookingRepository(
          bookings: [bookingFixture(id: 101)],
        );
        await _openPaymentFromMyBookings(tester, bookings);

        await tester.tap(find.text('Pay with PayOS'));
        await pumpFrames(tester);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await pumpRoute(tester);

        expect(bookings.verifiedIds, [101]);
        expect(find.text('Payment successful'), findsOneWidget);
        expect(find.textContaining(customerUser.email), findsOneWidget);

        await tester.tap(find.text('View my bookings'));
        await pumpRoute(tester);

        expect(find.text('My Bookings'), findsWidgets);
        expect(find.text('Confirmed'), findsOneWidget);
      },
    );

    testWidgets('Unpaid order keeps the customer on the payment screen', (
      WidgetTester tester,
    ) async {
      final bookings = FakeBookingRepository(
        bookings: [bookingFixture(id: 101)],
        verifyResult: paymentFixture(status: PaymentStatus.pending),
      );
      await _openPaymentFromMyBookings(tester, bookings);

      await tester.tap(find.text('Pay with PayOS'));
      await pumpFrames(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpFrames(tester);

      expect(bookings.verifiedIds, [101]);
      expect(find.text('Payment successful'), findsNothing);
      expect(find.text('Continue with PayOS'), findsOneWidget);
    });

    testWidgets('Background checks ask PayOS every 30 seconds', (
      WidgetTester tester,
    ) async {
      final bookings = FakeBookingRepository(
        bookings: [bookingFixture(id: 101, paymentId: 7)],
        verifyResult: paymentFixture(status: PaymentStatus.pending),
      );
      await _openPaymentFromMyBookings(tester, bookings);

      for (var second = 0; second < 25; second++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(bookings.verifiedIds, isEmpty);
      for (var second = 0; second < 6; second++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(bookings.verifiedIds, [101]);
      // The button stays usable while PayOS is asked in the background.
      final pay = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Continue with PayOS'),
      );
      expect(pay.onPressed, isNotNull);
    });

    testWidgets('PayOS redirect back to the web app verifies the payment', (
      WidgetTester tester,
    ) async {
      final bookings = FakeBookingRepository(
        bookings: [bookingFixture(id: 101)],
      );
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: bookings,
          paymentReturn: PayOsReturn.fromUri(
            Uri.parse(
              'http://localhost:8090/?code=00&id=abc&cancel=false&status=PAID&orderCode=101',
            ),
          ),
        ),
      );
      await pumpRoute(tester);

      expect(bookings.verifiedIds, [101]);
      expect(find.text('Payment successful'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await pumpRoute(tester);
      expect(find.text('Step Into CosmoQ Cinema'), findsOneWidget);
    });

    testWidgets('Cancelled PayOS payment shows payment not completed', (
      WidgetTester tester,
    ) async {
      final bookings = FakeBookingRepository(
        bookings: [bookingFixture(id: 101, status: BookingStatus.cancelled)],
        verifyResult: paymentFixture(status: PaymentStatus.failed),
      );
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: bookings,
          paymentReturn: const PayOsReturn(orderCode: 101, cancelled: true),
        ),
      );
      await pumpRoute(tester);

      expect(find.text('Payment not completed'), findsOneWidget);
      expect(
        find.textContaining('your seats have been released'),
        findsOneWidget,
      );
    });
  });

  group('My bookings', () {
    testWidgets('Active and History tabs open the booking detail', (
      WidgetTester tester,
    ) async {
      final bookings = FakeBookingRepository(
        bookings: [
          bookingFixture(id: 101, code: 'BK-PENDING'),
          bookingFixture(
            id: 102,
            code: 'BK-CONFIRMED',
            status: BookingStatus.confirmed,
            paymentId: 9,
          ),
          bookingFixture(
            id: 103,
            code: 'BK-CANCELLED',
            status: BookingStatus.cancelled,
          ),
          bookingFixture(
            id: 104,
            code: 'BK-EXPIRED',
            status: BookingStatus.expired,
          ),
        ],
      );
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: bookings,
          initialRoute: AppRoutes.myBookings,
        ),
      );
      await pumpRoute(tester);

      expect(find.text('Code: BK-PENDING'), findsOneWidget);
      expect(find.text('Code: BK-CONFIRMED'), findsOneWidget);
      expect(find.text('Code: BK-CANCELLED'), findsNothing);
      expect(find.text(formatVnd(180000)), findsWidgets);

      await tester.tap(find.text('Code: BK-PENDING'));
      await pumpRoute(tester);

      expect(find.text('Booking Detail'), findsWidgets);
      expect(find.text('Pay Now'), findsOneWidget);
      expect(find.text('Cancel Booking'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await pumpRoute(tester);

      await tester.tap(find.text('History'));
      await pumpRoute(tester);

      expect(find.text('Code: BK-CANCELLED'), findsOneWidget);
      expect(find.text('Code: BK-EXPIRED'), findsOneWidget);

      await tester.tap(find.text('Code: BK-CANCELLED'));
      await pumpRoute(tester);

      expect(find.text('BK-CANCELLED'), findsWidgets);
      expect(find.text('Cancel Booking'), findsNothing);
      expect(find.text('Pay Now'), findsNothing);
    });

    testWidgets('Cancelling a paid booking requests a refund', (
      WidgetTester tester,
    ) async {
      final bookings = FakeBookingRepository(
        bookings: [
          bookingFixture(
            id: 102,
            code: 'BK-CONFIRMED',
            status: BookingStatus.confirmed,
            paymentId: 9,
          ),
        ],
      );
      bookings.refund = Refund(
        id: 1,
        refundCode: 'RF-1',
        paymentId: 9,
        amount: 180000,
        status: 'PENDING',
        createdAt: DateTime.now(),
      );
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: bookings,
          initialRoute: AppRoutes.myBookings,
        ),
      );
      await pumpRoute(tester);

      await tester.tap(find.text('Code: BK-CONFIRMED'));
      await pumpRoute(tester);
      await tester.tap(find.text('Request refund'));
      await pumpRoute(tester);

      expect(find.textContaining('full refund'), findsOneWidget);
      await tester.tap(find.text('Request'));
      await pumpRoute(tester);
      await tester.pump(const Duration(seconds: 2));
      await pumpRoute(tester);

      expect(bookings.cancelledIds, [102]);
      expect(find.text('Refund pending'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await pumpRoute(tester);
      expect(
        find.text('Refund of ${formatVnd(180000)} in progress'),
        findsOneWidget,
      );
      expect(bookings.bookings.single.status, BookingStatus.refundPending);
      expect(find.text('Request refund'), findsNothing);
      Navigator.of(tester.element(find.text('Booking Detail'))).pop();
      await pumpRoute(tester);
      expect(find.text('Code: BK-CONFIRMED'), findsOneWidget);
      expect(find.text('Refund pending'), findsOneWidget);
      await tester.tap(find.text('History'));
      await pumpRoute(tester);
      expect(find.text('Code: BK-CONFIRMED'), findsNothing);
    });

    testWidgets('Paid booking close to the show cannot be cancelled', (
      WidgetTester tester,
    ) async {
      final bookings = FakeBookingRepository(
        bookings: [
          bookingFixture(
            id: 102,
            code: 'BK-SOON',
            status: BookingStatus.confirmed,
            paymentId: 9,
            showTime: DateTime.now().add(const Duration(hours: 1)),
          ),
        ],
      );
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: bookings,
          initialRoute: AppRoutes.myBookings,
        ),
      );
      await pumpRoute(tester);

      await tester.tap(find.text('Code: BK-SOON'));
      await pumpRoute(tester);

      expect(find.text('Cancel Booking'), findsNothing);
      expect(
        find.textContaining('up to 2 hours before the show'),
        findsOneWidget,
      );
    });
  });

  group('Account', () {
    testWidgets('Profile shows the user and signs out', (
      WidgetTester tester,
    ) async {
      final auth = FakeAuthRepository();
      final session = SessionState();
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          authRepository: auth,
          session: session,
        ),
      );
      await pumpRoute(tester);

      await tester.tap(find.byTooltip('Profile'));
      await pumpRoute(tester);

      expect(find.text(customerUser.fullName!), findsWidgets);
      expect(find.text(customerUser.email), findsWidgets);
      expect(find.text('Customer'), findsOneWidget);

      await tester.ensureVisible(find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
      await pumpRoute(tester);
      await tester.tap(find.text('Sign out').last);
      await pumpRoute(tester);

      expect(auth.logoutCalls, 1);
      expect(session.isAuthenticated, isFalse);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('Notifications show the email as plain text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(authenticated: true));
      await pumpRoute(tester);

      await tester.tap(find.byTooltip('Notifications'));
      await pumpRoute(tester);

      expect(find.text(notificationFixture.subject), findsOneWidget);

      await tester.tap(find.text(notificationFixture.subject));
      await pumpRoute(tester);

      expect(find.textContaining('Đặt vé thành công'), findsOneWidget);
      expect(find.textContaining('Phim: Inception & bạn'), findsOneWidget);
    });

    testWidgets('Forgot password sends a code and resets the password', (
      WidgetTester tester,
    ) async {
      final auth = FakeAuthRepository();
      await tester.pumpWidget(
        buildTestApp(authRepository: auth, initialRoute: AppRoutes.login),
      );
      await pumpRoute(tester);

      await tester.tap(find.text('Forgot password?'));
      await pumpRoute(tester);
      final sendCode = find.widgetWithText(AppButton, 'Send verification code');
      expect(sendCode, findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'khachhang1@gmail.com',
      );
      await tester.tap(sendCode);
      await pumpRoute(tester);

      expect(auth.forgotPasswordEmail, 'khachhang1@gmail.com');
      expect(
        find.text('Enter the verification code sent to khachhang1@gmail.com.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Verification code'),
        '654321',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'NewSecret1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'NewSecret1',
      );
      final resetButton = find.widgetWithText(AppButton, 'Reset password');
      await tester.ensureVisible(resetButton);
      await tester.pumpAndSettle();
      await tester.tap(resetButton);
      await pumpRoute(tester);

      expect(auth.resetOtp, '654321');
      expect(find.byKey(const Key('loginTitle')), findsOneWidget);
    });
  });
}

Future<void> _openSeatSelection(
  WidgetTester tester, {
  FakeCatalogRepository? catalogRepository,
  FakeBookingRepository? bookingRepository,
}) async {
  await tester.pumpWidget(
    buildTestApp(
      authenticated: true,
      catalogRepository: catalogRepository,
      bookingRepository: bookingRepository,
    ),
  );
  await pumpRoute(tester);

  await scrollHomeTo(tester, find.text(inception.title).first);
  await tester.tap(find.text(inception.title).first);
  await pumpRoute(tester);

  // Showtimes are listed on the movie detail screen.
  await tester.ensureVisible(find.text('Room 1'));
  await tester.pump();
  await tester.tap(find.text('Room 1'));
  await tester.pump();
  await tester.tap(find.text('Continue to Seats'));
  await pumpRoute(tester);
}

Future<void> _openPaymentFromMyBookings(
  WidgetTester tester,
  FakeBookingRepository bookings,
) async {
  await tester.pumpWidget(
    buildTestApp(
      authenticated: true,
      bookingRepository: bookings,
      initialRoute: AppRoutes.myBookings,
    ),
  );
  await pumpRoute(tester);

  await tester.tap(find.textContaining('Code: '));
  await pumpRoute(tester);
  await tester.tap(find.text('Pay Now'));
  await pumpFrames(tester);
}
