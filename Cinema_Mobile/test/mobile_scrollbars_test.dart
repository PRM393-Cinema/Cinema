import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('Mobile layouts hide automatic scrollbars and still scroll', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestApp());
    await pumpRoute(tester);
    final scrollbars = find.byWidgetPredicate(
      (widget) => widget is RawScrollbar,
    );
    expect(scrollbars, findsNothing);
    final homeScroll = find.byKey(const Key('homeScrollView'));
    final scrollable = find
        .descendant(of: homeScroll, matching: find.byType(Scrollable))
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, 0);
    await tester.drag(homeScroll, const Offset(0, -250));
    await pumpRoute(tester);
    expect(position.pixels, greaterThan(0));
    expect(scrollbars, findsNothing);

    tester.view.physicalSize = const Size(1024, 700);
    await pumpRoute(tester);
    expect(scrollbars, findsWidgets);
    tester.view.physicalSize = const Size(412, 700);
    await pumpRoute(tester);
    expect(scrollbars, findsNothing);

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.register);
    await pumpRoute(tester);
    expect(scrollbars, findsNothing);
    expect(
      ScrollConfiguration.of(tester.element(find.byType(Navigator)))
          .getPlatform(tester.element(find.byType(Navigator))),
      TargetPlatform.windows,
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
