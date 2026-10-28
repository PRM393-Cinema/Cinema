import 'package:cinema_fe/core/widgets/age_rating_badge.dart';
import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/data/models/booking_draft.dart';
import 'package:cinema_fe/data/models/movie.dart';
import 'package:cinema_fe/features/booking/screens/booking_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

const _rated = Movie(
  id: 1,
  title: 'Inception',
  description: 'A thief who steals secrets through dream-sharing.',
  durationMinutes: 148,
  genre: 'Sci-Fi, Action',
  language: 'English',
  releaseDate: null,
  posterUrl: '',
  trailerUrl: '',
  status: 'ACTIVE',
  ageRating: AgeRating.t16,
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('The API rating is read; a missing or unknown one is P', () {
    Map<String, Object?> json(Object? rating) => {
      'id': 1,
      'title': 'X',
      'ageRating': rating,
    };
    expect(Movie.fromJson(json('t18')).ageRating, AgeRating.t18);
    expect(Movie.fromJson(json(null)).ageRating, AgeRating.p);
    expect(Movie.fromJson(json('C18')).ageRating, AgeRating.p);
    expect(AgeRating.k.restricted, isTrue);
    expect(AgeRating.p.restricted, isFalse);
  });

  testWidgets('A rated movie shows its rating and asks before booking', (
    tester,
  ) async {
    final bookings = FakeBookingRepository();
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        catalogRepository: FakeCatalogRepository(movies: [_rated]),
        bookingRepository: bookings,
      ),
    );
    await pumpRoute(tester);

    await scrollHomeTo(tester, find.text(_rated.title).first);
    expect(find.byKey(const ValueKey('ageRating-T16')), findsWidgets);
    await tester.tap(find.text(_rated.title).first);
    await pumpRoute(tester);
    await tester.tap(find.text('View details'));
    await pumpRoute(tester);
    expect(find.text('16 and over'), findsOneWidget);

    await tester.ensureVisible(find.text('Room 1'));
    await tester.pump();
    await tester.tap(find.text('Room 1'));
    await tester.pump();
    await tester.tap(find.text('Continue to Seats'));
    await pumpRoute(tester);
    await tester.tap(find.text('1').last);
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await pumpRoute(tester);

    // Seats are already held; dismissing the age notice never starts payment.
    await tester.tap(find.text('Confirm Booking'));
    await pumpRoute(tester);
    expect(find.textContaining('only for viewers 16 and over'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await pumpRoute(tester);
    expect(bookings.createCalls, hasLength(1));
    expect(bookings.updateCalls, isEmpty);

    await tester.tap(find.text('Confirm Booking'));
    await pumpRoute(tester);
    await tester.tap(find.byKey(const Key('confirmAgeRating')));
    await pumpFrames(tester);
    expect(bookings.createCalls, hasLength(1));
    expect(bookings.updateCalls, hasLength(1));
  });

  testWidgets('A movie for all ages books without the notice', (tester) async {
    final bookings = FakeBookingRepository();
    await tester.pumpWidget(
      buildTestApp(authenticated: true, bookingRepository: bookings),
    );
    await pumpRoute(tester);
    await scrollHomeTo(tester, find.text(inception.title).first);
    await tester.tap(find.text(inception.title).first);
    await pumpRoute(tester);
    await tester.tap(find.text('View details'));
    await pumpRoute(tester);
    await tester.ensureVisible(find.text('Room 1'));
    await tester.pump();
    await tester.tap(find.text('Room 1'));
    await tester.pump();
    await tester.tap(find.text('Continue to Seats'));
    await pumpRoute(tester);
    await tester.tap(find.text('1').last);
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await pumpRoute(tester);

    await tester.tap(find.text('Confirm Booking'));
    await pumpFrames(tester);
    expect(find.byKey(const Key('confirmAgeRating')), findsNothing);
    expect(bookings.createCalls, hasLength(1));
  });

  testWidgets('Age notice fits small, landscape and large-text layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(
            arguments: BookingDraft(
              movie: _rated,
              showtime: showtimeFixture(),
              seats: [seatMapFixture.seats.first],
            ),
          ),
          builder: (_) =>
              BookingSummaryScreen(bookingRepository: FakeBookingRepository()),
        ),
      ),
    );
    await pumpRoute(tester);
    await tester.tap(find.text('Confirm Booking'));
    await pumpRoute(tester);
    final notice = tester.widget<AlertDialog>(find.byType(AlertDialog));

    // Isolate the notice from the booking page's own responsive layout.
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    for (final size in [
      const Size(375, 667),
      const Size(667, 375),
      const Size(1024, 768),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(2)),
            child: Scaffold(body: notice),
          ),
        ),
      );
      await pumpRoute(tester);
      expect(tester.takeException(), isNull);
      for (final label in ['I understand', 'Back']) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        );
        final rect = tester.getRect(button);
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(button.hitTestable(), findsOneWidget);
      }
    }
  });
}
