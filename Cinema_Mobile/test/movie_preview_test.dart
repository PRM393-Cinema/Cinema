@TestOn('vm')
library;

import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/core/widgets/trailer_preview.dart';
import 'package:cinema_fe/data/models/movie.dart';
import 'package:cinema_fe/features/movie/widgets/movie_preview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _movie = Movie(
  id: 1,
  title: 'Preview film',
  description: '',
  durationMinutes: 120,
  genre: '',
  language: '',
  releaseDate: null,
  posterUrl: '',
  trailerUrl: '',
  previewUrl: 'https://example.com/preview.mp4',
  status: 'ACTIVE',
);

void main() {
  testWidgets('Unsupported platforms still open details on the first tap', (
    tester,
  ) async {
    var opened = 0;
    await _card(tester, active: false, onOpen: () => opened++);
    await tester.tap(find.text(_movie.title));
    expect(opened, 1);
    expect(find.byType(TrailerPreview), findsNothing);
  });

  testWidgets('A tap on a loading preview opens details immediately', (
    tester,
  ) async {
    var opened = 0;
    final active = await _card(tester, onOpen: () => opened++);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(TrailerPreview)));
    await tester.pump();
    expect(opened, 1);
    expect(active.value, isNull);
    expect(find.byType(TrailerPreview), findsNothing);
  });

  for (final size in [const Size(375, 844), const Size(844, 375)]) {
    testWidgets('Inline playback and second tap fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = 0;
      final active = await _card(tester, onOpen: () => opened++);
      tester.widget<TrailerPreview>(find.byType(TrailerPreview)).onPlaying();
      await tester.pump(const Duration(seconds: 30));
      expect(active.value, _movie.id);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tapAt(tester.getCenter(find.byType(TrailerPreview)));
      await tester.pump();
      expect(opened, 1);
      expect(active.value, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Stop preview returns to the poster without opening details', (
    tester,
  ) async {
    var opened = 0;
    final active = await _card(tester, onOpen: () => opened++);
    await tester.tap(find.byTooltip('Stop preview'));
    await tester.pump();
    expect(active.value, isNull);
    expect(opened, 0);
    expect(find.byType(TrailerPreview), findsNothing);
  });

  testWidgets('Slow or blocked playback returns to the poster', (tester) async {
    final active = await _card(tester);
    await tester.pump(const Duration(seconds: 12));
    expect(active.value, isNull);
    expect(find.byType(TrailerPreview), findsNothing);
  });

  testWidgets('Video errors return to the poster and leave details usable', (
    tester,
  ) async {
    var opened = 0;
    final active = await _card(tester, onOpen: () => opened++);
    tester.widget<TrailerPreview>(find.byType(TrailerPreview)).onDone();
    await tester.pump();
    expect(active.value, isNull);
    await tester.tap(find.text(_movie.title));
    expect(opened, 1);
  });
}

Future<ValueNotifier<int?>> _card(
  WidgetTester tester, {
  bool active = true,
  VoidCallback? onOpen,
}) async {
  final selected = ValueNotifier<int?>(null);
  addTearDown(selected.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 160,
            height: 340,
            child: MoviePreviewCard(
              movie: _movie,
              active: selected,
              onOpen: onOpen ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
  if (active) {
    selected.value = _movie.id;
    await tester.pump();
  }
  return selected;
}
