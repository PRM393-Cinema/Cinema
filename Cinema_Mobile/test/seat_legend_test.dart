import 'package:cinema_fe/app/theme/app_colors.dart';
import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/features/seat/widgets/seat_item.dart';
import 'package:cinema_fe/features/seat/widgets/seat_legend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('Legend groups seat types and states at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: SeatLegend(
                  types: const {'NORMAL', 'VIP', 'SWEETBOX'},
                  priceOf: (type) => type == 'NORMAL'
                      ? 120000
                      : type == 'VIP'
                      ? 144000
                      : 156000,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final sweetboxWrap = tester.widget<Wrap>(
        find
            .ancestor(
              of: find.text('Sweetbox (couple)'),
              matching: find.byType(Wrap),
            )
            .first,
      );
      expect(sweetboxWrap.alignment, WrapAlignment.center);
      double top(String label) => tester.getTopLeft(find.text(label)).dy;
      if (scale == 1) {
        expect(top('Standard'), top('VIP'));
        expect(top('Selected'), top('Unavailable'));
        final sweetboxRow = find.ancestor(
          of: find.text('Sweetbox (couple)'),
          matching: find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.width == double.infinity,
          ),
        );
        expect(tester.getSize(sweetboxRow).width, 327);
        expect(find.text('${formatVnd(312000)} / pair'), findsOneWidget);
      }
      expect(top('Sweetbox (couple)'), greaterThan(top('VIP')));
      expect(top('Selected'), greaterThan(top('Sweetbox (couple)')));
      for (final label in [
        'Standard',
        'VIP',
        'Sweetbox (couple)',
        'Selected',
        'Unavailable',
      ]) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(375));
      }
      final booked = find.byWidgetPredicate(
        (w) => w is SeatItem && w.state == SeatItemState.booked,
      );
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: booked, matching: find.byType(DecoratedBox)),
      );
      expect(
        ((box.decoration as BoxDecoration).border! as Border).top.color,
        AppColors.error,
      );
      final icon = tester.widget<Icon>(
        find.descendant(of: booked, matching: find.byIcon(Icons.close_rounded)),
      );
      expect(icon.color, AppColors.error);
      expect(
        tester
            .widget<InkWell>(
              find.descendant(of: booked, matching: find.byType(InkWell)),
            )
            .onTap,
        isNull,
      );
    });
  }
}
