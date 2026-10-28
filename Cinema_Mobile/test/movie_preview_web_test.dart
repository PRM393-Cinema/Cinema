@TestOn('browser')
library;

import 'package:cinema_fe/core/widgets/trailer_preview.dart';
import 'package:cinema_fe/data/models/movie.dart';
import 'package:cinema_fe/features/movie/widgets/movie_preview_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const movie = Movie(
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
  testWidgets(
    'Hover waits, keeps playing beyond ten seconds, and stops on exit',
    (tester) async {
      final active = ValueNotifier<int?>(null);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 340,
              child: MoviePreviewCard(
                movie: movie,
                active: active,
                onOpen: () {},
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(600, 500));
      await mouse.moveTo(const Offset(100, 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(active.value, isNull);
      await tester.pump(const Duration(milliseconds: 100));
      expect(active.value, movie.id);
      tester.widget<TrailerPreview>(find.byType(TrailerPreview)).onPlaying();
      await tester.pump(const Duration(seconds: 30));
      expect(active.value, movie.id);
      await mouse.moveTo(const Offset(600, 500));
      await tester.pump();
      expect(active.value, isNull);
      await tester.pumpWidget(const SizedBox());
      await mouse.removePointer();
      active.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Phone tap previews and details remains a separate action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final active = ValueNotifier<int?>(null);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 340,
            child: MoviePreviewCard(
              movie: movie,
              active: active,
              onOpen: () => opened = true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(movie.title));
    await tester.pump();
    expect(active.value, movie.id);
    expect(opened, isFalse);
    await tester.tap(find.text('View details'));
    await tester.pump();
    expect(opened, isTrue);
    expect(active.value, isNull);
    await tester.pumpWidget(const SizedBox());
    active.dispose();
  });
}
