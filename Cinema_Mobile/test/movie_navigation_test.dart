import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/data/models/movie.dart';
import 'package:cinema_fe/features/movie/screens/movie_detail_screen.dart';
import 'package:cinema_fe/features/movie/widgets/movie_preview_card.dart';
import 'package:cinema_fe/features/movie/widgets/movie_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';
import 'support/fakes.dart';
import 'support/test_app.dart';

void main() {
  testWidgets(
    'Each movie opens its own details after going back and filtering',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final movies = movieFixtures
          .map(
            (movie) => Movie.fromJson({
              'id': movie.id,
              'title': movie.title,
              'description': movie.description,
              'durationMinutes': movie.durationMinutes,
              'genre': movie.genre,
              'previewUrl': 'https://example.com/${movie.id}.mp4',
              'status': 'ACTIVE',
            }),
          )
          .toList();
      await tester.pumpWidget(
        buildTestApp(catalogRepository: FakeCatalogRepository(movies: movies)),
      );
      await pumpRoute(tester);

      for (final movie in movieFixtures.reversed) {
        final card = find.byWidgetPredicate(
          (widget) => widget is MoviePreviewCard && widget.movie.id == movie.id,
        );
        await scrollHomeTo(tester, card);
        final posterCard = find.descendant(
          of: card,
          matching: find.byType(MovieCard),
        );
        final position = tester.getTopLeft(posterCard);
        tester.widget<MoviePreviewCard>(card).active.value = movie.id;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.getTopLeft(posterCard), position);
        await tester.tap(
          find.descendant(of: card, matching: find.text('View details')),
        );
        await pumpRoute(tester);

        final detail = find.byType(MovieDetailScreen);
        expect(tester.widget<MovieDetailScreen>(detail).movieId, movie.id);
        expect(
          ModalRoute.of(tester.element(detail))!.settings.name,
          AppRoutes.movieDetail(movie.id),
        );
        expect(find.text(movie.description), findsOneWidget);
        Navigator.of(tester.element(detail)).pop();
        await pumpRoute(tester);
      }

      await tester.drag(
        find.byKey(const Key('homeScrollView')),
        const Offset(0, 3000),
      );
      await pumpRoute(tester);
      await scrollHomeTo(tester, find.byKey(const Key('movieSearchField')));
      await tester.enterText(
        find.byKey(const Key('movieSearchField')),
        'inter',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await pumpRoute(tester);
      final card = find.byType(MoviePreviewCard);
      await scrollHomeTo(tester, card);
      await tester.tap(
        find.descendant(of: card, matching: find.text('Interstellar')),
      );
      await pumpRoute(tester);
      expect(
        tester
            .widget<MovieDetailScreen>(find.byType(MovieDetailScreen))
            .movieId,
        movieFixtures[1].id,
      );
      expect(find.text(movieFixtures[1].description), findsOneWidget);
    },
  );
}
