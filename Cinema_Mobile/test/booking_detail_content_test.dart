import 'package:cinema_fe/app/theme/app_colors.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/models/concession.dart';
import 'package:cinema_fe/data/models/payment.dart';
import 'package:cinema_fe/features/booking/widgets/booking_detail_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Booking sampleBooking({BookingStatus status = BookingStatus.refundPending}) =>
    Booking(
      id: 101,
      bookingCode: 'BK-20261101225826-305205',
      showtimeId: 11,
      status: status,
      totalAmount: 264000,
      paymentId: 18,
      movieTitle: 'Oppenheimer',
      showTime: DateTime(2026, 11, 2, 16),
      createdAt: DateTime(2026, 11, 1, 22, 58),
      expiresAt: status == BookingStatus.pending
          ? DateTime(2026, 11, 1, 23, 8)
          : null,
      seats: [
        for (final (i, label) in ['A5', 'B5', 'C5', 'C6'].indexed)
          BookingSeat(id: i, seatId: i, seatLabel: label, price: 180000),
      ],
      concessions: const [
        BookingConcession(
          itemId: 1,
          name: 'Combo Couple',
          unitPrice: 57000,
          quantity: 2,
        ),
      ],
      concessionsAmount: 114000,
      discountAmount: 570000,
      promotionName: 'Membership gifts',
      pointsEarned: 26,
    );

Refund sampleRefund({String status = 'PENDING', bool processed = false}) =>
    Refund(
      id: 1,
      refundCode: 'RF-20261102093000-123456',
      paymentId: 18,
      amount: 264000,
      status: status,
      createdAt: DateTime(2026, 11, 2, 9, 30),
      processedAt: processed ? DateTime(2026, 11, 2, 10) : null,
      note: status == 'REJECTED' ? 'Bank details could not be verified' : null,
    );

Widget contentApp({
  Booking? booking,
  Refund? refund,
  Brightness brightness = Brightness.dark,
}) => MaterialApp(
  theme: bookingDetailTheme(ThemeData(brightness: brightness)),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: BookingDetailContent(
        booking: booking ?? sampleBooking(),
        refund: refund,
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    for (final (family, file) in [
      ('BookingInter', 'Inter.ttf'),
      ('BookingLucide', 'lucide.ttf'),
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/booking-details/$file'))).load();
    }
  });

  for (final (width, scale) in [
    (320.0, 1.0),
    (412.0, 1.5),
    (768.0, 1.0),
    (1024.0, 1.0),
    (1440.0, 1.0),
    (1440.0, 2.0),
  ]) {
    testWidgets('Booking layout fits $width at $scale', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(contentApp(refund: sampleRefund()));
      await tester.pumpAndSettle();
      final info = tester.getRect(find.byKey(const Key('bookingInformation')));
      final payment = tester.getRect(
        find.byKey(const Key('bookingPaymentSummary')),
      );
      final seats = tester.getRect(
        find.byKey(const Key('bookingSeatsSection')),
      );
      final timeline = tester.getRect(find.byKey(const Key('bookingTimeline')));
      if (width >= 1024 && scale <= 1.6) {
        expect(info.top, payment.top);
        expect(info.width, closeTo(payment.width * 2, 1));
        expect(payment.left - info.right, closeTo(24, 1));
        expect(info.left, timeline.left);
        expect(seats.height, lessThan(130));
      } else {
        expect(info.left, payment.left);
        expect(payment.top, greaterThan(timeline.bottom));
      }
      for (final key in [
        'bookingInformation',
        'bookingPaymentSummary',
        'bookingRefundStatus',
        'bookingTimeline',
        'bookingSeatsSection',
      ]) {
        final rect = tester.getRect(find.byKey(Key(key)));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
      }
      expect(find.text('Combo Couple (2)'), findsOneWidget);
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text(formatVnd(834000)), findsOneWidget);
      expect(find.text('-${formatVnd(570000)}'), findsOneWidget);
      expect(find.text('Total Paid'), findsOneWidget);
      expect(find.text('Refund Pending'), findsOneWidget);
      expect(find.text(formatVnd(264000)), findsNWidgets(2));
      expect(find.text('26 points'), findsOneWidget);
      expect(find.text('C6'), findsOneWidget);
      expect(find.text('Paid'), findsNothing);
      expect(find.text('Cancelled'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final status in ['PENDING', 'COMPLETED', 'REJECTED']) {
    testWidgets('Refund timeline uses recorded $status timestamps', (
      tester,
    ) async {
      await tester.pumpWidget(
        contentApp(
          refund: sampleRefund(status: status, processed: status != 'PENDING'),
        ),
      );
      await tester.pumpAndSettle();
      final timeline = find.byKey(const Key('bookingTimeline'));
      expect(
        find.descendant(of: timeline, matching: find.text('Created')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: timeline, matching: find.text('Refund requested')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: timeline,
          matching: find.text(formatDateTime(DateTime(2026, 11, 2, 9, 30))),
        ),
        findsOneWidget,
      );
      if (status == 'PENDING') {
        expect(find.text('Refund completed'), findsNothing);
        expect(find.text('Refund rejected'), findsNothing);
      } else {
        expect(
          find.descendant(
            of: timeline,
            matching: find.text(
              status == 'COMPLETED' ? 'Refund completed' : 'Refund rejected',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: timeline,
            matching: find.text(formatDateTime(DateTime(2026, 11, 2, 10))),
          ),
          findsOneWidget,
        );
      }
      if (status == 'REJECTED') {
        expect(find.text('Rejection reason'), findsOneWidget);
        expect(find.text('Bank details could not be verified'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Pending refund without a record does not invent amount or time',
    (tester) async {
      await tester.pumpWidget(contentApp());
      await tester.pumpAndSettle();
      expect(find.text('Refund Pending'), findsOneWidget);
      expect(find.text('Refund Amount'), findsNothing);
      expect(find.text('Refund requested'), findsNothing);
    },
  );

  testWidgets('Copy code supports keyboard activation', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(contentApp());
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('copyBookingCode'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    // The selectable booking code precedes the copy button in focus order.
    for (var i = 0; i < 3 && copied == null; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      if (copied == null) await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    expect(button, findsOneWidget);
    expect(copied, sampleBooking().bookingCode);
    expect(find.text('Booking code copied'), findsOneWidget);
  });

  for (final status in BookingStatus.values) {
    testWidgets('$status preserves ticket visibility and total label', (
      tester,
    ) async {
      await tester.pumpWidget(
        contentApp(booking: sampleBooking(status: status)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ticketQr')),
        status == BookingStatus.confirmed ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Expires'),
        status == BookingStatus.pending ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Light theme remains readable', (tester) async {
    await tester.pumpWidget(
      contentApp(brightness: Brightness.light, refund: sampleRefund()),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(BookingDetailContent));
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.surface, const AppPalette(isLight: true).surface);
    expect(theme.colorScheme.onSurface.computeLuminance(), lessThan(0.1));
    expect(tester.takeException(), isNull);
  });
}
