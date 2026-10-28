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
  testWidgets('Active preview zooms visually and keeps its tap area fixed', (
    tester,
  ) async {
    var opened = 0;
    await _card(tester, onOpen: () => opened++);
    await tester.pump(const Duration(milliseconds: 150));
    final zoom = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(MoviePreviewCard),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(zoom.transform.storage[0], closeTo(1.08, 0.001));
    expect(zoom.transformHitTests, isFalse);
    await tester.tapAt(
      tester.getTopLeft(find.byType(MoviePreviewCard)) + const Offset(20, 40),
    );
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('Unavailable video still requires a preview tap before details', (
    tester,
  ) async {
    var opened = 0;
    await _card(tester, active: false, onOpen: () => opened++);
    await tester.tap(find.text(_movie.title));
    await tester.pump();
    expect(opened, 0);
    expect(find.text('Preview unavailable'), findsOneWidget);
    expect(find.byType(TrailerPreview), findsNothing);
    await tester.tap(find.text('View details'));
    expect(opened, 1);
  });

  testWidgets('The second tap opens details immediately', (tester) async {
    var opened = 0;
    final active = await _card(tester, onOpen: () => opened++);
    await tester.tapAt(tester.getCenter(find.byType(MoviePreviewCard)));
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
      await tester.pump(const Duration(seconds: 30));
      expect(active.value, _movie.id);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tapAt(tester.getCenter(find.byType(MoviePreviewCard)));
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

  testWidgets('Switching films always previews the newly tapped film first', (
    tester,
  ) async {
    final active = ValueNotifier<int?>(null);
    final opened = <int>[];
    final other = Movie.fromJson({'id': 2, 'title': 'Other film'});
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Row(
            children: [
              for (final movie in [_movie, other])
                SizedBox(
                  width: 160,
                  height: 340,
                  child: MoviePreviewCard(
                    movie: movie,
                    active: active,
                    onOpen: () => opened.add(movie.id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    for (final movie in [_movie, other, _movie]) {
      final card = find.byWidgetPredicate(
        (w) => w is MoviePreviewCard && w.movie.id == movie.id,
      );
      await tester.tapAt(tester.getTopLeft(card) + const Offset(40, 40));
      await tester.pump();
      expect(active.value, movie.id);
      expect(opened, isEmpty);
      expect(find.text('View details'), findsOneWidget);
    }
    await tester.tap(find.text('View details'));
    expect(opened, [_movie.id]);
    await tester.pumpWidget(const SizedBox());
    active.dispose();
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
