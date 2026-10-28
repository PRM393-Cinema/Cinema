import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/core/widgets/trailer_preview.dart';
import 'package:cinema_fe/data/models/movie.dart';
import 'package:cinema_fe/features/movie/widgets/movie_card.dart';
import 'package:cinema_fe/features/movie/widgets/movie_preview_sheet.dart';
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
  testWidgets('Preview and opening movie details are separate touch actions', (
    tester,
  ) async {
    var previews = 0;
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 340,
            child: MovieCard(
              title: _movie.title,
              onPreview: () => previews++,
              onTap: () => opened++,
            ),
          ),
        ),
      ),
    );
    final preview = find.byTooltip('Preview ${_movie.title}');
    expect(tester.getSize(preview).height, greaterThanOrEqualTo(48));
    await tester.tap(preview);
    expect(previews, 1);
    expect(opened, 0);
    await tester.tap(find.text(_movie.title));
    expect(opened, 1);
  });

  for (final size in [const Size(375, 844), const Size(844, 375)]) {
    testWidgets('Preview fits $size with large text and opens details', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = 0;
      await _openPreview(tester, onOpen: () => opened++, largeText: true);
      tester.widget<TrailerPreview>(find.byType(TrailerPreview)).onPlaying();
      await tester.pumpAndSettle();

      final video = tester.getRect(find.byType(AspectRatio));
      expect(video.width / video.height, closeTo(16 / 9, 0.01));
      expect(video.left, greaterThanOrEqualTo(0));
      expect(video.right, lessThanOrEqualTo(size.width));
      final details = find.text('View details');
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.byType(TrailerPreview), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Slow or blocked playback offers details and can be closed', (
    tester,
  ) async {
    await _openPreview(tester);
    await tester.pump(const Duration(seconds: 12));
    expect(find.textContaining('Preview unavailable'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
    expect(find.byType(TrailerPreview), findsNothing);
    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();
    expect(find.text(_movie.title), findsNothing);
  });

  testWidgets('Playback continues until an error and keeps details available', (
    tester,
  ) async {
    await _openPreview(tester);
    tester.widget<TrailerPreview>(find.byType(TrailerPreview)).onPlaying();
    await tester.pump(const Duration(seconds: 30));
    expect(find.byType(TrailerPreview), findsOneWidget);
    tester.widget<TrailerPreview>(find.byType(TrailerPreview)).onDone();
    await tester.pumpAndSettle();
    expect(find.textContaining('Preview unavailable'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();
  });

  testWidgets('Preview stops when the app goes into the background', (
    tester,
  ) async {
    await _openPreview(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(TrailerPreview), findsNothing);
    expect(find.byTooltip('Close preview'), findsNothing);
  });
}

Future<void> _openPreview(
  WidgetTester tester, {
  VoidCallback? onOpen,
  bool largeText = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(largeText ? 2 : 1),
          disableAnimations: largeText,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMoviePreview(context, _movie, onOpen ?? () {}),
            child: const Text('Open preview'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open preview'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
