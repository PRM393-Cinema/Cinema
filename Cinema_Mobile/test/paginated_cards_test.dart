import 'package:cinema_fe/core/widgets/paginated_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [375.0, 900.0, 1440.0]) {
    testWidgets('Ten cards per page, responsive columns at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var count = 23;
      var filter = 'all';
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SingleChildScrollView(
                  child: PaginatedCards(
                    itemCount: count,
                    resetKey: filter,
                    itemBuilder: (_, index) => SizedBox(
                      key: ValueKey('card-$index'),
                      height: 60,
                      child: Text('Item $index'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Item 9'), findsOneWidget);
      expect(find.text('Item 10'), findsNothing);
      final columns = width >= 900 ? 4 : 1;
      final first = tester.getRect(find.byKey(const ValueKey('card-0')));
      for (var index = 1; index < columns; index++) {
        final card = tester.getRect(find.byKey(ValueKey('card-$index')));
        expect(card.top, first.top);
        expect(card.width, closeTo(first.width, 1));
      }
      expect(
        tester.getRect(find.byKey(ValueKey('card-$columns'))).top,
        greaterThan(first.bottom),
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('previousPage')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Item 10'), findsOneWidget);
      expect(find.text('Item 19'), findsOneWidget);
      expect(find.text('Item 9'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('page-3')));
      await tester.pumpAndSettle();
      expect(find.text('Item 22'), findsOneWidget);
      expect(find.text('Item 23'), findsNothing);
      expect(
        tester.widget<IconButton>(find.byKey(const Key('nextPage'))).onPressed,
        isNull,
      );
      rebuild(() {
        count = 2;
      });
      await tester.pumpAndSettle();
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.byTooltip('Next page'), findsNothing);
      rebuild(() {
        count = 23;
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      rebuild(() {
        filter = 'filtered';
      });
      await tester.pumpAndSettle();
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Page 1 of 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
