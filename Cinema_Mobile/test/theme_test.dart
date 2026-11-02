import 'dart:ui' as ui;

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/app/theme/app_colors.dart';
import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/app/theme/theme_switch.dart';
import 'package:cinema_fe/core/widgets/app_button.dart';
import 'package:cinema_fe/core/widgets/cinema_account_widgets.dart';
import 'package:cinema_fe/core/widgets/cinema_background.dart';
import 'package:cinema_fe/features/auth/screens/login_screen.dart';
import 'package:cinema_fe/features/booking/widgets/booking_detail_content.dart';
import 'package:cinema_fe/features/movie/widgets/movie_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (first > second ? first + 0.05 : second + 0.05) /
      (first > second ? second + 0.05 : first + 0.05);
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'Booking details interpolate their colors throughout the transition',
    () {
      final dark = bookingDetailTheme(AppTheme.darkTheme);
      final light = bookingDetailTheme(AppTheme.lightTheme);
      for (final progress in [0.25, 0.49, 0.51, 0.75]) {
        final middle = bookingDetailTheme(
          ThemeData.lerp(AppTheme.darkTheme, AppTheme.lightTheme, progress),
        );
        expect(
          middle.scaffoldBackgroundColor,
          Color.lerp(
            dark.scaffoldBackgroundColor,
            light.scaffoldBackgroundColor,
            progress,
          ),
        );
        expect(
          middle.colorScheme.primary,
          Color.lerp(
            dark.colorScheme.primary,
            light.colorScheme.primary,
            progress,
          ),
        );
      }
    },
  );

  testWidgets('Theme transition reuses the painted backdrop layers', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.login));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ThemeSwitch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final backgrounds = find.descendant(
      of: find.byType(CinemaBackdropTransition),
      matching: find.byType(RepaintBoundary),
    );
    expect(backgrounds, findsNWidgets(2));
    final boundaries = tester
        .renderObjectList<RenderRepaintBoundary>(backgrounds)
        .toList();
    final pictures = boundaries
        .map((boundary) => (boundary.debugLayer! as OffsetLayer).firstChild)
        .toList();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      boundaries
          .map((boundary) => (boundary.debugLayer! as OffsetLayer).firstChild)
          .toList(),
      pictures,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('Palette interpolates every frame and repaints the backdrop', () {
    const dark = AppPalette(isLight: false);
    const light = AppPalette(isLight: true);
    final middle = dark.lerp(light, 0.4);
    expect(middle.lightness, 0.4);
    expect(
      middle.background,
      Color.lerp(dark.background, light.background, 0.4),
    );
    expect(
      middle.textPrimary,
      Color.lerp(dark.textPrimary, light.textPrimary, 0.4),
    );
    expect(middle.copyWith().lightness, middle.lightness);
    expect(
      CinemaBackdrop(logoCenter: Offset.zero, colors: middle).shouldRepaint(
        const CinemaBackdrop(logoCenter: Offset.zero, colors: dark),
      ),
      isTrue,
    );
  });

  for (final reduced in [false, true]) {
    testWidgets('Theme animation respects reduced motion: $reduced', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: reduced);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.login));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(LoginScreen));
      await tester.tap(find.byType(ThemeSwitch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final progress = AppPalette.of(context).lightness;
      if (reduced) {
        expect(progress, 1);
      } else {
        expect(progress, greaterThan(0));
        expect(progress, lessThan(1));
      }
      // A second tap during the transition must settle at the latest choice.
      await tester.tap(find.byType(ThemeSwitch));
      await tester.pumpAndSettle();
      expect(AppPalette.of(context).lightness, 0);
      expect(
        await const FlutterSecureStorage().read(key: 'appearance.theme'),
        'dark',
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final light in [false, true]) {
    testWidgets(
      'Poster stays crisp with transparent fractional edges: $light',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({
          'appearance.theme': light ? 'light' : 'dark',
        });
        tester.view.physicalSize = const Size(1800, 1125);
        tester.view.devicePixelRatio = 1.25;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();
        final poster = tester.widget<Stack>(
          find.byKey(const Key('featuredPoster')).first,
        );
        final palette = AppPalette(isLight: light);
        expect(
          tester
              .widget<ImageFiltered>(
                find.byKey(const Key('featuredPosterBackdrop')).first,
              )
              .enabled,
          isTrue,
        );
        expect(
          tester
              .widget<ImageFiltered>(
                find.byKey(const Key('featuredPosterForeground')).first,
              )
              .enabled,
          isFalse,
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 568,
                  height: 368,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: ColoredBox(color: palette.primary)),
                          Expanded(child: ColoredBox(color: palette.accent)),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Transform.translate(
                          offset: const Offset(0.35, 0.25),
                          child: poster,
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
        final pixels = await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.25);
          try {
            return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          } finally {
            image.dispose();
          }
        });
        void expectPixel(int x, int y, Color expected) {
          final offset = ((y * 1.25).round() * 710 + (x * 1.25).round()) * 4;
          expect(
            Color.fromARGB(
              255,
              pixels!.getUint8(offset),
              pixels.getUint8(offset + 1),
              pixels.getUint8(offset + 2),
            ),
            expected,
            reason: 'Pixel ($x, $y) must not have a theme wash',
          );
        }

        for (var x = 0; x < 568; x++) {
          for (final y in [
            0,
            12,
            23,
            24,
            25,
            29,
            338,
            342,
            343,
            344,
            355,
            367,
          ]) {
            expectPixel(x, y, x < 284 ? palette.primary : palette.accent);
          }
        }
        for (var y = 0; y < 368; y++) {
          for (final x in [
            0,
            12,
            23,
            24,
            25,
            29,
            538,
            542,
            543,
            544,
            555,
            567,
          ]) {
            expectPixel(x, y, x < 284 ? palette.primary : palette.accent);
          }
        }
        expectPixel(336, 184, palette.surfaceSoft);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final light in [false, true]) {
    testWidgets(
      'Controls use solid surfaces and a clear focus border: light=$light',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
            home: Scaffold(
              body: CinemaPanel(
                child: AppButton(
                  label: 'Continue',
                  useGradient: true,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        for (final box in tester.widgetList<DecoratedBox>(
          find.byType(DecoratedBox),
        )) {
          final decoration = box.decoration;
          if (decoration is BoxDecoration && decoration.gradient != null) {
            expect(decoration.gradient!.colors.toSet().length, 1);
            expect(
              decoration.gradient!.colors.first,
              AppPalette(isLight: light).surface,
            );
          }
        }
        final style = tester
            .widget<ElevatedButton>(find.byType(ElevatedButton))
            .style!;
        expect(
          style.backgroundColor!.resolve({}),
          AppPalette(isLight: light).primary,
        );
        final inputs = Theme.of(tester.element(find.byType(CinemaPanel)))
            .inputDecorationTheme;
        expect(
          inputs.focusedBorder!.borderSide.width,
          greaterThan(inputs.enabledBorder!.borderSide.width),
        );
      },
    );
  }

  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('Light home keeps search usable at $width', (tester) async {
      FlutterSecureStorage.setMockInitialValues({'appearance.theme': 'light'});
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      final search = find.byKey(const Key('movieSearchField'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Inception');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(MovieCard, 'Inception'), findsOneWidget);
      expect(find.text('Interstellar'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final light in [false, true]) {
    test('${light ? 'Light' : 'Dark'} palette keeps text readable', () {
      final colors = AppPalette(isLight: light);
      for (final background in [
        colors.background,
        colors.surface,
        colors.surfaceSoft,
      ]) {
        expect(
          contrast(colors.textPrimary, background),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(colors.textSecondary, background),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrast(colors.primary, background), greaterThanOrEqualTo(4.5));
      }
      expect(
        contrast(colors.onPrimary, colors.primary),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('Theme switch preserves the current page at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.login));
      await tester.pumpAndSettle();
      final field = find.byType(TextFormField).first;
      await tester.enterText(field, 'viewer@example.com');
      await tester.tap(find.byType(ThemeSwitch));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('viewer@example.com'), findsOneWidget);
      final context = tester.element(find.byType(LoginScreen));
      expect(Theme.of(context).brightness, Brightness.light);
      expect(
        Theme.of(context).scaffoldBackgroundColor,
        const AppPalette(isLight: true).background,
      );
      expect(
        await const FlutterSecureStorage().read(key: 'appearance.theme'),
        'light',
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(ThemeSwitch));
      await tester.pumpAndSettle();
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(find.text('viewer@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Stored light preference is restored on the customer website', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'appearance.theme': 'light'});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(ThemeSwitch))).brightness,
      Brightness.light,
    );
    await tester.tap(find.byType(ThemeSwitch));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(ThemeSwitch))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Primary and danger buttons keep contrasting labels in light mode',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                AppButton(label: 'Book', onPressed: () {}),
                AppButton.danger(label: 'Cancel', onPressed: () {}),
              ],
            ),
          ),
        ),
      );
      for (final button in tester.widgetList<ElevatedButton>(
        find.byType(ElevatedButton),
      )) {
        final style = button.style!;
        expect(
          contrast(
            style.foregroundColor!.resolve({})!,
            style.backgroundColor!.resolve({})!,
          ),
          greaterThanOrEqualTo(4.5),
        );
      }
    },
  );
}
