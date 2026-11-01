import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> open(WidgetTester tester, {bool single = false}) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      buildTestApp(
        catalogRepository: FakeCatalogRepository(
          movies: single ? [inception] : movieFixtures,
        ),
      ),
    );
    await pumpRoute(tester);
  }

  String position(WidgetTester tester) {
    final pages = tester.widget<PageView>(
      find.descendant(
        of: find.byKey(const Key('featuredCarousel')),
        matching: find.byType(PageView),
      ),
    );
    return '${pages.controller!.page!.round() + 1} / ${pages.childrenDelegate.estimatedChildCount}';
  }

  Color? arrowColor(WidgetTester tester, IconData icon) =>
      IconTheme.of(tester.element(find.byIcon(icon))).color;

  Future<void> advance(WidgetTester tester, Duration duration) async {
    await tester.pump(duration);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  testWidgets(
    'Featured movies rotate every five seconds and controls stay inside',
    (tester) async {
      await open(tester);
      final banner = tester.getRect(find.byKey(const Key('featuredCarousel')));
      for (final label in ['Next featured movie', 'Previous featured movie']) {
        final control = tester.getRect(find.byTooltip(label));
        expect(banner.contains(control.topLeft), isTrue);
        expect(banner.contains(control.bottomRight), isTrue);
      }
      final previous = tester.getRect(
        find.byTooltip('Previous featured movie'),
      );
      final next = tester.getRect(find.byTooltip('Next featured movie'));
      expect(previous.center.dx, lessThan(banner.center.dx));
      expect(next.center.dx, greaterThan(banner.center.dx));
      expect(previous.center.dy, closeTo(banner.center.dy, 1));
      expect(next.center.dy, closeTo(banner.center.dy, 1));
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
      expect(find.byKey(const Key('featuredPosition')), findsNothing);
      expect(
        arrowColor(tester, Icons.chevron_left_rounded),
        AppColors.textPrimary.withValues(alpha: 0.25),
      );
      expect(
        arrowColor(tester, Icons.chevron_right_rounded),
        AppColors.textPrimary.withValues(alpha: 0.25),
      );
      expect(position(tester), '1 / 3');
      await advance(tester, const Duration(seconds: 4));
      expect(position(tester), '1 / 3');
      await advance(tester, const Duration(seconds: 1));
      expect(position(tester), '2 / 3');
      await advance(tester, const Duration(seconds: 5));
      expect(position(tester), '3 / 3');
      await advance(tester, const Duration(seconds: 5));
      expect(position(tester), '1 / 3');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Manual navigation restarts idle timer', (tester) async {
    await open(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byTooltip('Next featured movie'));
    await pumpRoute(tester);
    expect(position(tester), '2 / 3');
    await advance(tester, const Duration(seconds: 4));
    expect(position(tester), '2 / 3');
    await advance(tester, const Duration(seconds: 1));
    expect(position(tester), '3 / 3');
    await tester.tap(find.byTooltip('Previous featured movie'));
    await pumpRoute(tester);
    expect(position(tester), '2 / 3');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Swiping changes movie and its details button opens that film', (
    tester,
  ) async {
    await open(tester);
    await tester.drag(
      find.byKey(const Key('featuredCarousel')),
      const Offset(-900, 0),
    );
    await pumpRoute(tester);
    expect(position(tester), '2 / 3');
    final details = find.descendant(
      of: find.byKey(const Key('featuredCarousel')),
      matching: find.text('View Details'),
    );
    await tester.tap(details);
    await pumpRoute(tester);
    expect(
      ModalRoute.of(tester.element(find.text('Interstellar').first))
          ?.settings
          .name,
      AppRoutes.movieDetail(2),
    );
  });

  testWidgets('Hovering the banner does not stop five-second rotation', (
    tester,
  ) async {
    await open(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(0, 0));
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('featuredCarousel'))),
    );
    await tester.pump();
    await advance(tester, const Duration(seconds: 5));
    expect(
      arrowColor(tester, Icons.chevron_left_rounded),
      AppColors.textPrimary.withValues(alpha: 0.25),
    );
    expect(
      arrowColor(tester, Icons.chevron_right_rounded),
      AppColors.textPrimary.withValues(alpha: 0.25),
    );
    expect(position(tester), '2 / 3');
    await advance(tester, const Duration(seconds: 5));
    expect(position(tester), '3 / 3');
    await mouse.moveTo(const Offset(0, 0));
    await tester.pump();
    await advance(tester, const Duration(seconds: 5));
    expect(
      arrowColor(tester, Icons.chevron_left_rounded),
      AppColors.textPrimary.withValues(alpha: 0.25),
    );
    expect(
      arrowColor(tester, Icons.chevron_right_rounded),
      AppColors.textPrimary.withValues(alpha: 0.25),
    );
    expect(position(tester), '1 / 3');
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Keyboard focus pauses rotation and leaving resumes it', (
    tester,
  ) async {
    await open(tester);
    Focus.of(tester.element(find.byIcon(Icons.chevron_right_rounded)))
        .requestFocus();
    await tester.pump();
    await advance(tester, const Duration(seconds: 10));
    expect(position(tester), '1 / 3');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await advance(tester, const Duration(seconds: 5));
    expect(position(tester), '2 / 3');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Only the hovered arrow brightens and its background stays transparent',
    (tester) async {
      await open(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(0, 0));
      for (final icon in [
        Icons.chevron_left_rounded,
        Icons.chevron_right_rounded,
      ]) {
        await mouse.moveTo(tester.getCenter(find.byIcon(icon)));
        await tester.pumpAndSettle();
        expect(arrowColor(tester, icon), AppColors.textPrimary);
        final other = icon == Icons.chevron_left_rounded
            ? Icons.chevron_right_rounded
            : Icons.chevron_left_rounded;
        expect(
          arrowColor(tester, other),
          AppColors.textPrimary.withValues(alpha: 0.25),
        );
        final button = tester.widget<IconButton>(
          find
              .ancestor(
                of: find.byIcon(icon),
                matching: find.byType(IconButton),
              )
              .first,
        );
        expect(
          button.style!.backgroundColor!.resolve({WidgetState.hovered}),
          Colors.transparent,
        );
        expect(
          button.style!.overlayColor!.resolve({WidgetState.hovered}),
          Colors.transparent,
        );
      }
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Reduced motion disables auto rotation but manual navigation works',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await open(tester);
      await advance(tester, const Duration(seconds: 30));
      expect(position(tester), '1 / 3');
      await tester.tap(find.byTooltip('Next featured movie'));
      await pumpRoute(tester);
      expect(position(tester), '2 / 3');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('A single featured film needs no carousel controls', (
    tester,
  ) async {
    await open(tester, single: true);
    expect(find.byTooltip('Next featured movie'), findsNothing);
    await advance(tester, const Duration(seconds: 30));
    expect(find.byKey(const Key('featuredCarousel')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
