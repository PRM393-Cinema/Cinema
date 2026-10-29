import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/app/theme/app_colors.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/network/api_exception.dart';
import 'package:cinema_fe/data/models/review.dart';
import 'package:cinema_fe/data/repositories/booking_repository.dart';
import 'package:cinema_fe/data/services/booking_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';
import 'support/test_app.dart';

Map<String, Object?> _review(int id, String? title, int stars) => {
  'id': id,
  'movieId': id,
  'movieTitle': title,
  'bookingId': 100 + id,
  'reviewerName': 'Jane',
  'rating': stars,
  'comment': 'Comment $id',
  'createdAt': '2026-10-0${id}T10:00:00',
  'updatedAt': '2026-10-0${id}T10:00:00',
  'mine': true,
};

List<MovieReview> _reviews() => [
  MovieReview.fromJson(_review(1, 'Inception', 4)),
  MovieReview.fromJson(_review(2, 'Interstellar', 5)),
  MovieReview.fromJson(_review(3, 'Oppenheimer', 4)),
];

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'My ratings reads the existing mine endpoint including movie titles',
    () async {
      final repository = RemoteBookingRepository(
        service: BookingService(
          client: ApiClient(
            httpClient: MockClient((request) async {
              expect(request.method, 'GET');
              expect(request.url.path, '/api/v1/reviews/mine');
              expect(request.url.queryParameters, isEmpty);
              return http.Response(
                jsonEncode([_review(1, 'Inception', 4), _review(2, null, 5)]),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        ),
      );
      final reviews = await repository.getMyReviews();
      expect(reviews.map((review) => review.movieLabel), [
        'Inception',
        'Movie #2',
      ]);
      expect(reviews.first.rating, 4);
      expect(reviews.first.mine, isTrue);
    },
  );

  for (final width in [375.0, 1280.0]) {
    testWidgets('Ratings opens beside tickets at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: FakeBookingRepository()..myReviews = _reviews(),
        ),
      );
      await pumpRoute(tester);
      final entry = find.byKey(const Key('myRatings'));
      await tester.tap(entry);
      await pumpRoute(tester);
      expect(find.text('3 ratings · Newest first'), findsOneWidget);
      expect(find.text('Oppenheimer'), findsOneWidget);
      final searchTop = tester
          .getTopLeft(find.byKey(const Key('ratingMovieFilter')))
          .dy;
      final ratingTop = tester
          .getTopLeft(find.byKey(const Key('ratingStarsFilter')))
          .dy;
      expect(searchTop, ratingTop);
      final searchRect = tester.getRect(
        find.byKey(const Key('ratingMovieFilter')),
      );
      final ratingRect = tester.getRect(
        find.byKey(const Key('ratingStarsFilter')),
      );
      expect(searchRect.right, lessThan(ratingRect.left));
      expect(searchRect.height, closeTo(ratingRect.height, 1));
      expect(find.text('All ratings'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ratingStarsFilter')));
      await pumpRoute(tester);
      final menuItem = find.byType(PopupMenuItem<int>).first;
      final menuRect = tester.getRect(menuItem);
      expect(menuRect.width, closeTo(ratingRect.width, 1));
      expect(menuRect.left, closeTo(ratingRect.left, 1));
      final menuSurface = tester.widget<Material>(
        find.ancestor(of: menuItem, matching: find.byType(Material)).first,
      );
      expect(menuSurface.color, AppColors.surfaceSoft);
      await tester.tap(find.text('4 stars').last);
      await pumpRoute(tester);
      expect(find.text('4 stars'), findsOneWidget);
      expect(find.text('2 ratings · Newest first'), findsOneWidget);
      expect(find.text('Interstellar'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Movie name and star filters combine and show no-match state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        bookingRepository: FakeBookingRepository()..myReviews = _reviews(),
        initialRoute: AppRoutes.myRatings,
      ),
    );
    await pumpRoute(tester);
    await tester.enterText(find.byType(TextFormField), ' INCEPTION ');
    await tester.pump();
    expect(find.text('Inception'), findsOneWidget);
    expect(find.text('Interstellar'), findsNothing);
    await _selectStars(tester, 5);
    expect(find.text('No matching ratings'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ratingStarsFilter')));
    await pumpRoute(tester);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(
      tester.getSize(find.byType(PopupMenuItem<int>).first).width,
      lessThanOrEqualTo(280),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpRoute(tester);
    expect(find.text('No matching ratings'), findsOneWidget);
    await _selectStars(tester, null);
    expect(find.text('Inception'), findsOneWidget);
    await tester.tap(find.text('Inception'));
    await pumpRoute(tester);
    expect(find.text('Movie Detail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ratings handles load errors, retry and an empty history', (
    tester,
  ) async {
    final repository = _RetryReviews();
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        bookingRepository: repository,
        initialRoute: AppRoutes.myRatings,
      ),
    );
    await pumpRoute(tester);
    expect(find.text('Unable to load ratings'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Retry'));
    await pumpRoute(tester);
    expect(find.text('No ratings yet'), findsOneWidget);
  });

  for (final size in [const Size(320, 812), const Size(844, 375)]) {
    testWidgets('Personal ratings stays readable at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: FakeBookingRepository()..myReviews = _reviews(),
          initialRoute: AppRoutes.myRatings,
        ),
      );
      await pumpRoute(tester);
      expect(find.byKey(const Key('ratingMovieFilter')), findsOneWidget);
      await _selectStars(tester, 1);
      expect(find.text('No matching ratings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('A guest cannot open personal ratings', (tester) async {
    await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.myRatings));
    await pumpRoute(tester);
    expect(find.byKey(const Key('loginTitle')), findsOneWidget);
    expect(find.byKey(const Key('ratingMovieFilter')), findsNothing);
  });
}

Future<void> _selectStars(WidgetTester tester, int? stars) async {
  final dropdown = find.byKey(const Key('ratingStarsFilter'));
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await pumpRoute(tester);
  final option = find
      .text(
        stars == null ? 'All ratings' : '$stars star${stars == 1 ? '' : 's'}',
      )
      .last;
  await tester.ensureVisible(option);
  await tester.tap(option);
  await pumpRoute(tester);
}

class _RetryReviews extends FakeBookingRepository {
  bool fail = true;
  @override
  Future<List<MovieReview>> getMyReviews() async {
    if (fail) throw const ApiException(statusCode: 503, message: 'Unavailable');
    return super.getMyReviews();
  }
}
