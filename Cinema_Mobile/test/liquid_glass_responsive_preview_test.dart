import 'dart:ui' as ui;

import 'package:cinema_fe/core/widgets/cinema_account_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [375.0, 390.0, 412.0]) {
    testWidgets('liquid navigation fits ${width.toInt()} px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: const _PreviewScreen(selectedIndex: 1),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Tickets'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      for (final label in ['Home', 'Tickets', 'Account']) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.style!.color!.a, 1);
      }
      for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(icon.color!.a, 1);
      }
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CinemaNavigationBar && widget.selectedIndex == 1,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      final glass = tester.getRect(find.byType(BackdropFilter).first);
      expect(glass.left, greaterThanOrEqualTo(12));
      expect(glass.right, lessThanOrEqualTo(width - 12));
      expect(glass.bottom, lessThanOrEqualTo(844 - 34 - 12));
    });
  }

  testWidgets('rounded lens bends the background along its capsule edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final backgroundKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: key,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CinemaGlassBackground(
                key: backgroundKey,
                child: CustomPaint(painter: _RefractionMarker()),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CinemaNavigationBar(
                  selectedIndex: 0,
                  backgroundKey: backgroundKey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _waitForLens(tester);
    List<int>? initialPeaks;
    for (final height in [260.0, 844.0]) {
      tester.view.physicalSize = Size(390, height);
      await tester.pump();
      await _waitForLens(tester);
      final glass = tester.getRect(find.byType(BackdropFilter).first);
      final pixels = await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        try {
          return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        } finally {
          image.dispose();
        }
      });

      int greenAt(int x, int y) => pixels!.getUint8((y * 390 + x) * 4 + 1);

      int linePeak(int y) {
        var brightest = -1;
        var peak = 22;
        for (var x = 22; x <= 52; x++) {
          final green = greenAt(x, y);
          if (green > brightest) {
            brightest = green;
            peak = x;
          }
        }
        return peak;
      }

      final peaks = <int>[];
      // A straight source stripe bends smoothly around the rounded end of the lens.
      for (final inset in [7, 18, 30, 44]) {
        final y = glass.top.toInt() + inset;
        final peak = linePeak(y);
        peaks.add(peak);
        expect(greenAt(peak, y) - greenAt(peak + 9, y), greaterThan(25));
      }
      expect(
        peaks.map((x) => (x - 43).abs()).reduce((a, b) => a > b ? a : b),
        greaterThanOrEqualTo(5),
      );
      expect(peaks.toSet().length, greaterThanOrEqualTo(3));
      int redContrast(int inset) {
        final index = ((glass.top.toInt() + inset) * 390 + 260) * 4;
        return pixels!.getUint8(index) - pixels.getUint8(index + 1);
      }

      // Refraction preserves the orientation of the source rather than mirroring it.
      expect(redContrast(14), greaterThan(60));
      expect(redContrast(62), lessThan(15));
      // Fine source detail is softened, while the broad color markers remain visible.
      var fineDetailPeak = 0;
      final detailY = glass.top.toInt() + 12;
      for (var x = 218; x <= 242; x++) {
        final value = greenAt(x, detailY);
        if (value > fineDetailPeak) fineDetailPeak = value;
      }
      expect(fineDetailPeak, lessThan(130));
      // Moving the bar must not move the optical origin away from its center.
      if (initialPeaks != null) expect(peaks, initialPeaks);
      initialPeaks = peaks;
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('web lens updates while scrolling without repaint feedback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backgroundKey = GlobalKey();
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: captureKey,
          child: Scaffold(
            extendBody: true,
            body: CinemaGlassBackground(
              key: backgroundKey,
              child: ListView(
                padding: EdgeInsets.zero,
                children: const [
                  SizedBox(
                    height: 300,
                    child: ColoredBox(color: Color(0xFFDC4020)),
                  ),
                  SizedBox(
                    height: 600,
                    child: ColoredBox(color: Color(0xFF208040)),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: CinemaNavigationBar(
              selectedIndex: 0,
              backgroundKey: backgroundKey,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _waitForLens(tester);
    final initialPainter = tester.widget<CustomPaint>(_lensFinder).painter;

    Future<int> redMinusGreen() async {
      final glass = tester.getRect(find.byType(BackdropFilter).first);
      return (await tester.runAsync(() async {
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final pixels = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        final index = ((glass.top.toInt() + 34) * 390 + 260) * 4;
        return pixels!.getUint8(index) - pixels.getUint8(index + 1);
      }))!;
    }

    expect(await redMinusGreen(), greaterThan(60));
    await tester.drag(find.byType(ListView), const Offset(0, -170));
    await tester.pumpAndSettle();
    await _waitForLens(tester, after: initialPainter);
    expect(await redMinusGreen(), lessThan(-35));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}

final _lensFinder = find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint &&
      widget.painter.runtimeType.toString() == '_GlassSnapshotPainter',
);

Future<void> _waitForLens(WidgetTester tester, {CustomPainter? after}) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (_lensFinder.evaluate().isNotEmpty &&
        tester.widget<CustomPaint>(_lensFinder).painter != after &&
        !tester.binding.hasScheduledFrame) {
      return;
    }
  }
  expect(_lensFinder, findsOneWidget);
  expect(tester.widget<CustomPaint>(_lensFinder).painter, isNot(after));
  expect(tester.binding.hasScheduledFrame, isFalse);
}

class _RefractionMarker extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF122634),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 88 + 12, size.width, 16),
      Paint()..color = const Color(0xFFFF4020),
    );
    canvas.drawRect(
      Rect.fromLTWH(40, 0, 6, size.height),
      Paint()..color = const Color(0xFF91BFA9),
    );
    canvas.drawRect(
      Rect.fromLTWH(220, 0, 1, size.height),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PreviewScreen extends StatelessWidget {
  const _PreviewScreen({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF142334), Color(0xFF321C3A), Color(0xFF122820)],
            ),
          ),
        ),
        Positioned(
          left: -36,
          top: 110,
          width: 186,
          height: 300,
          child: _poster(const [Color(0xFFDC9D43), Color(0xFF2B5664)]),
        ),
        Positioned(
          right: -24,
          top: 190,
          width: 190,
          height: 280,
          child: _poster(const [Color(0xFF2C9BA0), Color(0xFFBD6688)]),
        ),
        Positioned(
          left: 104,
          top: 70,
          width: 168,
          height: 250,
          child: _poster(const [Color(0xFF7A537C), Color(0xFF344778)]),
        ),
      ],
    ),
    bottomNavigationBar: CinemaNavigationBar(selectedIndex: selectedIndex),
  );

  Widget _poster(List<Color> colors) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
    ),
  );
}
