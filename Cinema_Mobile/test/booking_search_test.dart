import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/test_app.dart';

class SearchBookingsRepository extends FakeBookingRepository {
  SearchBookingsRepository()
    : super(
        bookings: [
          for (var index = 0; index < 13; index++)
            Booking(
              id: index + 1,
              bookingCode: 'BK-SEARCH-$index',
              showtimeId: 11,
              status: BookingStatus.refundPending,
              totalAmount: 180000,
              movieTitle: index == 12 ? 'Mưa đỏ' : 'Inception',
              createdAt: DateTime(2026, 11, 1),
              seats: const [],
            ),
          Booking(
            id: 99,
            bookingCode: 'BK-PAST',
            showtimeId: 11,
            status: BookingStatus.cancelled,
            totalAmount: 180000,
            movieTitle: 'Mưa đỏ',
            createdAt: DateTime(2026, 11, 1),
            seats: const [],
          ),
        ],
      );
  int loads = 0;
  @override
  Future<List<Booking>> getMyBookings(int userId) async {
    loads++;
    return super.getMyBookings(userId);
  }
}

void main() {
  for (final theme in ['light', 'dark']) {
    for (final width in [375.0, 1440.0]) {
      testWidgets(
        'Booking search filters all pages and both tabs: $theme/$width',
        (tester) async {
          FlutterSecureStorage.setMockInitialValues({
            'appearance.theme': theme,
          });
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final repository = SearchBookingsRepository();
          await tester.pumpWidget(
            buildTestApp(
              authenticated: true,
              initialRoute: AppRoutes.myBookings,
              bookingRepository: repository,
            ),
          );
          await pumpRoute(tester);
          final field = find.descendant(
            of: find.byKey(const Key('bookingSearch')),
            matching: find.byType(TextFormField),
          );
          for (final query in ['  bk-search-12  ', 'MƯA ĐỎ']) {
            await tester.enterText(field, query);
            await pumpRoute(tester);
            expect(
              find.byKey(const ValueKey('bookingCard-13')),
              findsOneWidget,
            );
            expect(find.byKey(const ValueKey('bookingCard-1')), findsNothing);
          }
          await tester.tap(find.text('History'));
          await pumpRoute(tester);
          expect(find.byKey(const ValueKey('bookingCard-99')), findsOneWidget);
          await tester.enterText(field, 'does-not-exist');
          await pumpRoute(tester);
          expect(find.text('No matching bookings.'), findsOneWidget);
          await tester.tap(find.byKey(const Key('clearBookingSearch')));
          await pumpRoute(tester);
          expect(find.byKey(const ValueKey('bookingCard-99')), findsOneWidget);
          expect(repository.loads, 1);
          await tester.tap(find.text('Active'));
          await pumpRoute(tester);
          await tester.enterText(field, 'BK-SEARCH-12');
          await pumpRoute(tester);
          final navigator = Navigator.of(tester.element(field));
          await tester.tap(find.byKey(const ValueKey('bookingCard-13')));
          await pumpRoute(tester);
          expect(find.text('Booking Detail'), findsOneWidget);
          navigator.pop();
          await pumpRoute(tester);
          expect(
            tester.widget<TextFormField>(field).controller!.text,
            'BK-SEARCH-12',
          );
          expect(find.byKey(const ValueKey('bookingCard-13')), findsOneWidget);
          expect(repository.loads, 2);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Changing the search resets booking pagination', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'appearance.theme': 'light'});
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        initialRoute: AppRoutes.myBookings,
        bookingRepository: SearchBookingsRepository(),
      ),
    );
    await pumpRoute(tester);
    await tester.ensureVisible(find.byKey(const Key('nextPage')));
    await pumpRoute(tester);
    await tester.tap(find.byKey(const Key('nextPage')));
    await pumpRoute(tester);
    expect(find.text('Page 2 of 2'), findsOneWidget);
    final field = find.descendant(
      of: find.byKey(const Key('bookingSearch')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field, 'Inception');
    await pumpRoute(tester);
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('bookingCard-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
