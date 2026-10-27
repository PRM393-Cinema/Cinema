import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/models/movie.dart';
import 'package:cinema_fe/data/models/paged_result.dart';
import 'package:cinema_fe/data/models/review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

final _nolan = Movie(
  id: inception.id,
  title: inception.title,
  description: inception.description,
  durationMinutes: inception.durationMinutes,
  genre: inception.genre,
  language: inception.language,
  releaseDate: null,
  posterUrl: '',
  trailerUrl: '',
  status: 'ACTIVE',
  director: 'Christopher Nolan',
  cast: 'Leonardo DiCaprio, Elliot Page',
);

MovieReview _review({
  int id = 1,
  int rating = 5,
  String name = 'Tran Thi B',
  String? comment = 'Mind-bending!',
  bool mine = false,
}) {
  final at = DateTime(2026, 10, 20, 21);
  return MovieReview(
    id: id,
    movieId: inception.id,
    bookingId: 300 + id,
    reviewerName: name,
    rating: rating,
    comment: comment,
    createdAt: at,
    updatedAt: at,
    mine: mine,
  );
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Reviews read the average and the count per star', () {
    final reviews = MovieReviews.fromJson({
      'movieId': 1,
      'average': 4.3,
      'count': 3,
      'stars': [0, 0, 0, 2, 1],
      'reviews': {
        'items': [
          {
            'id': 7,
            'movieId': 1,
            'bookingId': 9,
            'reviewerName': 'kha***@gmail.com',
            'rating': 4,
            'createdAt': '2026-10-20T21:00:00',
            'updatedAt': '2026-10-21T08:00:00',
            'mine': true,
          },
        ],
        'pageNumber': 1,
        'totalPages': 1,
        'totalCount': 3,
      },
    });
    expect(reviews.stars, [0, 0, 0, 2, 1]);
    final review = reviews.reviews.items.single;
    expect(review.mine, isTrue);
    expect(review.edited, isTrue);
    expect(review.comment, isNull);
  });

  testWidgets('The movie page shows the director, cast and reviews', (
    tester,
  ) async {
    final catalog = FakeCatalogRepository(movies: [_nolan])
      ..reviews[inception.id] = MovieReviews(
        movieId: inception.id,
        average: 4.5,
        count: 2,
        stars: const [0, 0, 0, 1, 1],
        reviews: PagedResult(
          items: [
            _review(),
            _review(id: 2, rating: 4, name: 'Le Van C', comment: null),
          ],
          pageNumber: 1,
          totalPages: 1,
          totalCount: 2,
        ),
      );
    await tester.pumpWidget(
      buildTestApp(
        catalogRepository: catalog,
        initialRoute: AppRoutes.movieDetail(inception.id),
      ),
    );
    await pumpRoute(tester);

    expect(find.text('Director: Christopher Nolan'), findsOneWidget);
    expect(find.text('Cast: Leonardo DiCaprio, Elliot Page'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Mind-bending!'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('2 reviews'), findsOneWidget);
    expect(find.text('Le Van C'), findsOneWidget);
  });

  testWidgets('A checked-in ticket writes, edits and deletes its review', (
    tester,
  ) async {
    final watched = bookingFixture(
      id: 401,
      status: BookingStatus.confirmed,
      paymentId: 9,
      checkedInAt: DateTime.now().subtract(const Duration(hours: 3)),
    );
    final bookings = FakeBookingRepository(bookings: [watched])
      ..bookingReviews[401] = BookingReview(
        bookingId: 401,
        movieId: inception.id,
        canReview: true,
      );
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        bookingRepository: bookings,
        initialRoute: AppRoutes.bookingDetail(401),
      ),
    );
    await pumpRoute(tester);

    await tester.ensureVisible(find.byKey(const Key('writeReview')));
    await tester.tap(find.byKey(const Key('writeReview')));
    await pumpRoute(tester);
    // Stars are required.
    await tester.tap(find.byKey(const Key('saveReview')));
    await tester.pump();
    expect(find.text('Choose 1 to 5 stars.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('star-4')));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('reviewCommentField')),
        matching: find.byType(TextFormField),
      ),
      ' Great sound ',
    );
    await tester.tap(find.byKey(const Key('saveReview')));
    await pumpRoute(tester);
    expect(bookings.savedReviews.single, (
      bookingId: 401,
      rating: 4,
      comment: 'Great sound',
    ));
    expect(find.text('Great sound'), findsOneWidget);
    expect(find.text('Nguyen Van Khach (you)'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('deleteReview')));
    await tester.tap(find.byKey(const Key('deleteReview')));
    await pumpRoute(tester);
    await tester.tap(find.byKey(const Key('confirmDeleteReview')));
    await pumpRoute(tester);
    expect(bookings.deletedReviews, [501]);
    expect(find.byKey(const Key('writeReview')), findsOneWidget);
  });

  testWidgets('A ticket not checked in yet cannot be reviewed', (tester) async {
    final paid = bookingFixture(
      id: 402,
      status: BookingStatus.confirmed,
      paymentId: 9,
    );
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        bookingRepository: FakeBookingRepository(bookings: [paid]),
        initialRoute: AppRoutes.bookingDetail(402),
      ),
    );
    await pumpRoute(tester);

    await tester.ensureVisible(find.byKey(const Key('ticketReview')));
    expect(find.textContaining('once your ticket'), findsOneWidget);
    expect(find.byKey(const Key('writeReview')), findsNothing);
  });
}
