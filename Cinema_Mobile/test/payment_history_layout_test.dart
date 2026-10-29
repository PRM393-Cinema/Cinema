import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/data/models/payment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('Empty payment history remains refreshable', (tester) async {
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
