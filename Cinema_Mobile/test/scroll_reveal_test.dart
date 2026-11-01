import 'package:cinema_fe/core/widgets/scroll_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Reveal waits for visible content and remains onscreen after animating',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: scroll,
              children: const [
                SizedBox(height: 590),
                ScrollReveal(
                  child: SizedBox(height: 200, child: Text('Slow reveal')),
                ),
                SizedBox(height: 800),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final opacity = find.descendant(
        of: find.byType(ScrollReveal),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(opacity).opacity, 0);
      scroll.jumpTo(150);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      scroll.jumpTo(180);
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(opacity).opacity, 1);
    },
  );

  for (final reduced in [false, true]) {
    testWidgets('Scroll reveal enters once; reduced motion=$reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: const [
                    SizedBox(height: 900),
                    ScrollReveal(
                      child: SizedBox(
                        height: 200,
                        child: Text('Revealed section'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final opacity = find.descendant(
        of: find.byType(ScrollReveal),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(opacity).opacity, reduced ? 1 : 0);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -550),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 550),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
