import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/test_app.dart';

class _Genres extends FakeCatalogRepository {
  @override
  Future<List<String>> getGenres() async => [
    'Khoa học viễn tưởng',
    for (var i = 0; i < 15; i++) 'Thể loại $i',
  ];
}

void main() {
  for (final (size, scale) in [
    (const Size(375, 844), 1.0),
    (const Size(320, 812), 1.5),
    (const Size(844, 375), 1.0),
    (const Size(1280, 768), 1.0),
  ]) {
    testWidgets('Home menus match filters at $size, scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final catalog = _Genres();
      await tester.pumpWidget(buildTestApp(catalogRepository: catalog));
      await pumpRoute(tester);
      for (final key in ['showingFilter', 'genreFilter']) {
        final field = find.byKey(Key(key));
        await scrollHomeTo(tester, field);
        final fieldRect = tester.getRect(field);
        await tester.tap(field);
        await pumpRoute(tester);
        final items = find.byWidgetPredicate((w) => w is PopupMenuItem);
        expect(items, findsWidgets);
        expect(tester.getSize(items.first).width, closeTo(fieldRect.width, 1));
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(
          tester
              .widget<Text>(
                find
                    .text(key == 'showingFilter' ? 'Now showing' : 'All genres')
                    .last,
              )
              .overflow,
          isNot(TextOverflow.ellipsis),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await pumpRoute(tester);
        expect(items, findsNothing);
        expect(catalog.browseCalls.last.genre, isNull);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(const Key('genreFilter')));
      await pumpRoute(tester);
      await tester.ensureVisible(find.text('Khoa học viễn tưởng').last);
      await pumpRoute(tester);
      await tester.tap(find.text('Khoa học viễn tưởng').last);
      await pumpRoute(tester);
      expect(catalog.browseCalls.last.genre, 'Khoa học viễn tưởng');
      expect(find.text('Khoa học viễn tưởng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
