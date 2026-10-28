import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/data/models/movie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

final _release = DateUtils.dateOnly(DateTime.now())
    .add(const Duration(days: 10));

final _titanic = Movie(
  id: 9,
  title: 'Titanic',
  description: 'Jack and Rose on the ship.',
  durationMinutes: 194,
  genre: 'Romance, Drama',
  language: 'English',
  releaseDate: _release,
  posterUrl: '',
  trailerUrl: '',
  status: 'ACTIVE',
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('A movie released after today is coming soon', () {
    expect(_titanic.isComingSoon(), isTrue);
    expect(movieFixtures[1].isComingSoon(), isFalse);
    expect(inception.isComingSoon(), isFalse); // No release date.
  });

  testWidgets('Home splits now showing and coming soon, and filters genres', (
    tester,
  ) async {
    final catalog = FakeCatalogRepository(movies: [...movieFixtures, _titanic]);
    await tester.pumpWidget(buildTestApp(catalogRepository: catalog));
    await pumpRoute(tester);

    expect(catalog.browseCalls.single.comingSoon, isFalse);
    await scrollHomeTo(tester, find.text('Oppenheimer').first);
    expect(find.text('Titanic'), findsNothing);

    // Coming soon: the release date on the poster.
    await _scrollHomeToTop(tester);
    await tester.tap(find.byKey(const Key('showingFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coming soon').last);
    await pumpRoute(tester);
    expect(catalog.browseCalls.last.comingSoon, isTrue);
    expect(find.text('Coming Soon'), findsOneWidget);
    await scrollHomeTo(tester, find.text('Titanic'));
    expect(find.text(formatShortDate(_release)), findsOneWidget);
    expect(find.text('Oppenheimer'), findsNothing);

    // Back to now showing, only dramas.
    await _scrollHomeToTop(tester);
    await tester.tap(find.byKey(const Key('showingFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Now showing').last);
    await pumpRoute(tester);
    await tester.ensureVisible(find.byKey(const Key('genreFilter')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('genreFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drama').last);
    await pumpRoute(tester);
    expect(catalog.browseCalls.last.genre, 'Drama');
    await scrollHomeTo(tester, find.text('Oppenheimer').first);
    expect(find.text('Interstellar'), findsNothing);

    // Searching asks the server once the customer stops typing.
    await _scrollHomeToTop(tester);
    await tester.tap(find.byKey(const Key('genreFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All genres').last);
    await pumpRoute(tester);
    await _scrollHomeToTop(tester);
    await tester.enterText(find.byKey(const Key('movieSearchField')), 'nope');
    await pumpRoute(tester);
    expect(catalog.browseCalls.last.keyword, 'nope');
    await scrollHomeTo(tester, find.text('No movies found'));
    expect(find.text('No movies found'), findsOneWidget);
  });

  testWidgets('A movie coming soon says when it opens', (tester) async {
    final catalog = FakeCatalogRepository(
      movies: [...movieFixtures, _titanic],
      showtimes: const [],
    );
    await tester.pumpWidget(
      buildTestApp(
        catalogRepository: catalog,
        initialRoute: AppRoutes.movieDetail(_titanic.id),
      ),
    );
    await pumpRoute(tester);

    expect(find.text('Coming ${formatDate(_release)}'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Opens ${formatDate(_release)}'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Opens ${formatDate(_release)}'), findsOneWidget);
  });
}

// The tabs and the search field are at the top of the home list.
Future<void> _scrollHomeToTop(WidgetTester tester) async {
  await tester.fling(
    find
        .descendant(
          of: find.byKey(const Key('homeScrollView')),
          matching: find.byType(Scrollable),
        )
        .first,
    const Offset(0, 4000),
    4000,
  );
  await pumpRoute(tester);
}
