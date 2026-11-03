import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/data/models/payment.dart';
import 'package:cinema_fe/features/admin/widgets/revenue_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Payment summary retains exact daily revenue and supports older servers',
    () {
      final summary = PaymentSummary.fromJson({
        'revenue': 350000,
        'paidCount': 3,
        'refundedAmount': 30000,
        'dailyRevenue': [
          {'date': '2026-11-01T00:00:00', 'revenue': 150000},
          {'date': '2026-11-03T00:00:00', 'revenue': 200000},
        ],
      });
      expect(
        summary.dailyRevenue!.fold(0.0, (sum, row) => sum + row.$2),
        summary.revenue,
      );
      expect(summary.dailyRevenue!.last.$1.day, 3);
      expect(PaymentSummary.fromJson({'revenue': 0}).dailyRevenue, isNull);
      expect(
        PaymentSummary.fromJson({'revenue': 0, 'dailyRevenue': []})
            .dailyRevenue,
        isEmpty,
      );
    },
  );

  for (final dark in [true, false]) {
    for (final width in [375.0, 1440.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('Daily chart dark=$dark width=$width scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final days = [
            for (var day = 1; day <= 31; day++)
              (DateTime(2026, 10, day), day == 31 ? 770000.0 : 0.0),
          ];
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(child: RevenueChart(days: days)),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final plot = find.byKey(const Key('revenueLinePlot'));
          final painter =
              tester.widget<CustomPaint>(plot).painter! as RevenueLinePainter;
          expect(painter.values.length, 31);
          expect(painter.values.last, 770000);
          expect(painter.maximum, 770000);
          expect(
            tester
                .widget<DropdownButton<int>>(
                  find.byKey(const Key('revenueDaySelector')),
                )
                .value,
            30,
          );
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          await mouse.moveTo(tester.getTopLeft(plot) + const Offset(5, 50));
          await tester.pump();
          expect(
            tester
                .widget<DropdownButton<int>>(
                  find.byKey(const Key('revenueDaySelector')),
                )
                .value,
            0,
          );
          await mouse.removePointer();
          await tester.tap(find.byKey(const Key('revenueDaySelector')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('02/10 · ${formatVnd(0)}').last);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<DropdownButton<int>>(
                  find.byKey(const Key('revenueDaySelector')),
                )
                .value,
            1,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('Single zero day draws safely and explains the empty period', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RevenueChart(days: [(DateTime(2026, 11, 1), 0)])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No revenue recorded this month.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
