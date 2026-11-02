import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/core/widgets/cinema_background.dart';
import 'package:cinema_fe/core/widgets/cinema_account_widgets.dart';
import 'package:cinema_fe/data/models/payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'support/fakes.dart';
import 'support/test_app.dart';

PaymentInfo sample(PaymentStatus status) => PaymentInfo(
  id: 1,
  paymentCode: 'PAY-2026-TDM001',
  bookingId: 101,
  amount: 180000,
  status: status,
  method: 'VNPAY',
  transactionRef: 'VNPAY_REF_99887766',
  createdAt: DateTime(2026, 10, 7, 23, 45),
);

class HistoryRepository extends FakeBookingRepository {
  HistoryRepository(this.payments);
  final List<PaymentInfo> payments;
  @override
  Future<List<PaymentInfo>> getMyPayments(int userId) async => payments;
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final theme in ['light', 'dark']) {
    for (final width in [900.0, 1440.0, 1920.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('$theme desktop payment table fits $width at $scale', (
          tester,
        ) async {
          FlutterSecureStorage.setMockInitialValues({
            'appearance.theme': theme,
          });
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final payments = [
            for (var index = 0; index < 8; index++)
              PaymentInfo(
                id: index + 1,
                paymentCode: 'PAY-20261101225943-${159011 + index}',
                bookingId: 101,
                amount: 264000 + index * 1000,
                status:
                    PaymentStatus.values[index % PaymentStatus.values.length],
                method: index == 0 ? null : 'PAYOS',
                transactionRef: index == 0 ? null : '59930520$index',
                createdAt: DateTime(2026, 11, 1, 22, 59),
              ),
          ];
          await tester.pumpWidget(
            buildTestApp(
              authenticated: true,
              bookingRepository: HistoryRepository(payments),
              initialRoute: AppRoutes.paymentHistory,
            ),
          );
          await pumpRoute(tester);
          final table = tester.widget<DataTable>(
            find.byKey(const Key('paymentHistoryTable')),
          );
          expect(
            table.columns.map(
              (column) => ((column.label as Expanded).child as Text).data,
            ),
            ['Payment ID', 'Date', 'Amount', 'Method', 'Status', 'Action'],
          );
          expect(table.rows.length, 8);
          expect(table.columns[2].numeric, isTrue);
          expect(table.dataRowMinHeight, 56 * scale);
          expect(table.dataRowMaxHeight, double.infinity);
          expect(find.byType(CinemaBackdropTransition), findsOneWidget);
          expect(
            Theme.of(tester.element(find.byType(Scaffold).last))
                .scaffoldBackgroundColor,
            Colors.transparent,
          );
          expect(find.text('Not specified'), findsOneWidget);
          expect(find.text('Ref: 599305201'), findsOneWidget);
          for (final label in [
            'Paid',
            'Pending',
            'Failed',
            'Refund pending',
            'Refunded',
            'Unknown',
          ]) {
            expect(find.text(label), findsWidgets);
          }
          if (scale == 1) {
            final lastAction = tester.getRect(
              find.byKey(const ValueKey('paymentBooking-8')),
            );
            expect(lastAction.bottom, lessThan(900));
            expect(
              tester.getSize(find.byType(DataTable)).width,
              lessThanOrEqualTo(width),
            );
          }
          expect(tester.takeException(), isNull);
          final action = find.byKey(const ValueKey('paymentBooking-1'));
          await tester.ensureVisible(action);
          await pumpRoute(tester);
          await tester.tap(action);
          await pumpRoute(tester);
          expect(find.text('Booking Detail'), findsOneWidget);
          expect(find.byType(CinemaBackdropTransition), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final (width, light) in [(375.0, false), (375.0, true)]) {
    testWidgets('Payment cards are preserved at width=$width, light=$light', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({
        'appearance.theme': light ? 'light' : 'dark',
      });
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: HistoryRepository([sample(PaymentStatus.success)]),
          initialRoute: AppRoutes.paymentHistory,
        ),
      );
      await pumpRoute(tester);
      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(CinemaPanel), findsOneWidget);
      expect(find.text('VNPAY_REF_99887766'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(formatVnd(180000))).style!.fontSize,
        32,
      );
      expect(find.byType(CinemaBackdropTransition), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final (status, label, icon) in [
    (PaymentStatus.success, 'Paid', Icons.check_circle_outline),
    (PaymentStatus.failed, 'Failed', Icons.error_outline),
    (PaymentStatus.pending, 'Pending', Icons.schedule_outlined),
    (
      PaymentStatus.refundPending,
      'Refund pending',
      Icons.hourglass_top_rounded,
    ),
    (PaymentStatus.refunded, 'Refunded', Icons.undo_rounded),
    (PaymentStatus.unknown, 'Unknown', Icons.help_outline),
  ]) {
    testWidgets('$label history keeps the amount and booking link', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: HistoryRepository([sample(status)]),
          initialRoute: AppRoutes.paymentHistory,
        ),
      );
      await pumpRoute(tester);
      expect(find.text(label), findsOneWidget);
      expect(find.byIcon(icon), findsOneWidget);
      expect(find.text(formatVnd(180000)), findsOneWidget);
      expect(find.text('VNPAY_REF_99887766'), findsOneWidget);
      await tester.ensureVisible(find.text('View booking #101'));
      await tester.tap(find.text('View booking #101'));
      await pumpRoute(tester);
      expect(find.text('Booking Detail'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final (size, scale) in [
    (const Size(320, 812), 1.5),
    (const Size(375, 812), 3.2),
    (const Size(844, 375), 1.0),
  ]) {
    testWidgets('Payment history fits $size at scale $scale', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final payment = PaymentInfo(
        id: 1,
        paymentCode: 'PAY-2026-TEST-LONG-REFERENCE-001',
        bookingId: 101,
        amount: 110000,
        status: PaymentStatus.refundPending,
        method: null,
        transactionRef: '',
        createdAt: DateTime(2026, 10, 7),
      );
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: HistoryRepository([payment]),
          initialRoute: AppRoutes.paymentHistory,
        ),
      );
      await pumpRoute(tester);
      expect(find.text('Not specified'), findsOneWidget);
      expect(find.text('Transaction reference'), findsNothing);
      await tester.ensureVisible(find.text('View booking #101'));
      await pumpRoute(tester);
      expect(tester.takeException(), isNull);
    });
  }
  for (final light in [false, true]) {
    testWidgets('Empty payment history remains refreshable: light=$light', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({
        'appearance.theme': light ? 'light' : 'dark',
      });
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: HistoryRepository([]),
          initialRoute: AppRoutes.paymentHistory,
        ),
      );
      await pumpRoute(tester);
      expect(find.text('No payments yet'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  }
}
