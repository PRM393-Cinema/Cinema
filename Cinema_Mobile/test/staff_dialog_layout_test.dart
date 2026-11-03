import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/features/staff/widgets/staff_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final light in [true, false]) {
    for (final size in [
      const Size(1920, 1080),
      const Size(375, 844),
      const Size(844, 390),
    ]) {
      testWidgets(
        'Staff input stays compact and validates in light=$light at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          String? value;
          await tester.pumpWidget(
            MaterialApp(
              theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async => value = await staffInput(
                      context,
                      'Rename room',
                      'Room name',
                      initial: 'Room 1',
                      maxLength: 8,
                    ),
                    child: const Text('Rename'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Rename'));
          await tester.pumpAndSettle();
          // Dialog includes the route's outside padding; measure its material.
          final bounds = tester.getRect(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(bounds.width, lessThanOrEqualTo(480));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(size.width));
          final fields = find.byType(TextFormField);
          await tester.enterText(fields, '  ');
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
          expect(find.text('Required.'), findsOneWidget);
          expect(value, isNull);
          await tester.enterText(fields, '123456789');
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
          expect(find.text('Maximum 8 characters.'), findsOneWidget);
          await tester.enterText(fields, ' Room 2 ');
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
          expect(value, 'Room 2');
          expect(find.byType(Dialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
