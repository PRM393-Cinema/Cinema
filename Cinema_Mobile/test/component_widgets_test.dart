import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/core/widgets/app_button.dart';
import 'package:cinema_fe/core/widgets/status_badge.dart';
import 'package:cinema_fe/features/seat/widgets/seat_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppButton renders label', (WidgetTester tester) async {
    await tester.pumpWidget(
      _TestApp(
        child: AppButton(label: 'Book Now', onPressed: () {}),
      ),
    );

    expect(find.text('Book Now'), findsOneWidget);
  });

  testWidgets('AppButton disabled and loading states render safely', (
    WidgetTester tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      _TestApp(
        child: Column(
          children: [
            AppButton(label: 'Disabled'),
            AppButton(
              label: 'Loading',
              isLoading: true,
              onPressed: () => taps++,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Disabled'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(taps, 0);
  });

  testWidgets(
    'Page button style overrides defaults and keeps disabled behavior',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: AppButton(
            label: 'Styled action',
            trailingIcon: Icons.arrow_forward_rounded,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              side: BorderSide.none,
            ),
          ),
        ),
      );
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      expect(
        button.style!.backgroundColor!.resolve({WidgetState.disabled}),
        Colors.transparent,
      );
      expect(button.style!.side!.resolve({}), BorderSide.none);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    },
  );

  testWidgets('StatusBadge renders label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const _TestApp(
        child: StatusBadge(
          label: 'Confirmed',
          variant: StatusBadgeVariant.success,
        ),
      ),
    );

    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('SeatItem renders all supported states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _TestApp(
        child: Wrap(
          children: [
            SeatItem(label: 'A1'),
            SeatItem(label: 'A2', state: SeatItemState.selected),
            SeatItem(label: 'A3', state: SeatItemState.held),
            SeatItem(label: 'A4', state: SeatItemState.booked),
          ],
        ),
      ),
    );

    expect(find.text('A1'), findsOneWidget);
    expect(find.text('A2'), findsOneWidget);
    expect(find.text('A3'), findsOneWidget);
    expect(find.text('A4'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: Center(child: child)),
    );
  }
}
