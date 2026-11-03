import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/features/staff/widgets/shift_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final light in [false, true]) {
    for (final width in [375.0, 844.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Shift charts fit light=$light width=$width text=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            MaterialApp(
              theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: TextScaler.linear(scale),
                ),
                child: const Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: ShiftCharts(
                        sold: 40,
                        held: 5,
                        checkedIn: 33,
                        withBookings: 3,
                        showtimes: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.text('15%'), findsOneWidget);
          expect(find.text('With bookings  3'), findsOneWidget);
          expect(find.text('Without bookings  17'), findsOneWidget);
          expect(
            find.bySemanticsLabel('3 of 20 showtimes have bookings'),
            findsOneWidget,
          );
          expect(find.byTooltip('Sold: 40 tickets'), findsOneWidget);
          expect(find.byTooltip('Held: 5 tickets'), findsOneWidget);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        });
      }
    }
  }
  testWidgets('No activity uses empty bars and an honest empty donut', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShiftCharts(
              sold: 0,
              held: 0,
              checkedIn: 0,
              withBookings: 0,
              showtimes: 0,
            ),
          ),
        ),
      ),
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.text('No ticket activity yet today.'), findsOneWidget);
    expect(find.text('100%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
