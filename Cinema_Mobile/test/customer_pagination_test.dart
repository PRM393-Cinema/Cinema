import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/widgets/paginated_cards.dart';
import 'package:cinema_fe/core/widgets/cinema_page.dart';
import 'package:cinema_fe/data/models/app_notification.dart';
import 'package:cinema_fe/data/models/movie.dart';
import 'package:cinema_fe/data/models/review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final route in [
    AppRoutes.home,
    AppRoutes.myBookings,
    AppRoutes.myRatings,
    AppRoutes.notifications,
  ]) {
    testWidgets('$route shows ten cards then three, with four columns', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      final repository =
          FakeBookingRepository(
              bookings: [
                for (var i = 0; i < 13; i++)
                  bookingFixture(id: 101 + i, code: 'BK-$i'),
              ],
              notifications: [
                for (var i = 0; i < 13; i++)
                  AppNotification(
                    id: i + 1,
                    subject: 'Entry $i',
                    type: 'BOOKING_CONFIRMED',
                    content: '<p>Booking update $i</p>',
                    status: 'SENT',
                    createdAt: now,
                  ),
              ],
            )
            ..myReviews = [
              for (var i = 0; i < 13; i++)
                MovieReview(
                  id: i + 1,
                  movieId: i + 1,
                  bookingId: 101 + i,
                  reviewerName: 'Customer',
                  movieTitle: 'Entry $i',
                  rating: 4,
                  createdAt: now,
                  updatedAt: now,
                ),
            ];
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          initialRoute: route,
          bookingRepository: repository,
          catalogRepository: FakeCatalogRepository(
            movies: [
              for (var i = 0; i < 13; i++)
                Movie.fromJson({
                  'id': i + 1,
                  'title': 'Entry $i',
                  'status': 'ACTIVE',
                  'durationMinutes': 120,
                }),
            ],
          ),
        ),
      );
      await pumpRoute(tester);
      if (route != AppRoutes.home) {
        expect(find.byType(CinemaPageHeader), findsNothing);
        expect(find.text('Browse movies'), findsNothing);
      }
      final grid = find.byType(PaginatedCards);
      final cards = find.descendant(
        of: grid,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data?.startsWith('Entry ') == true ||
                  widget.data?.startsWith('Code: BK-') == true),
        ),
      );
      expect(cards, findsNWidgets(10));
      final first = tester.getRect(cards.at(0));
      for (var i = 1; i < 4; i++) {
        expect(tester.getRect(cards.at(i)).top, closeTo(first.top, 1));
        expect(tester.getRect(cards.at(i)).left, greaterThan(first.left));
      }
      await tester.ensureVisible(find.byKey(const Key('nextPage')));
      await pumpRoute(tester);
      await tester.tap(find.byKey(const Key('nextPage')));
      await pumpRoute(tester);
      expect(cards, findsNWidgets(3));
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byKey(const Key('nextPage'))).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
