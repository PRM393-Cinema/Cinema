import 'package:cinema_fe/app/app.dart';
import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/data/mock/mock_movies.dart';
import 'package:cinema_fe/features/booking/screens/booking_detail_screen.dart';
import 'package:cinema_fe/features/booking/screens/my_bookings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const CinemaApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Login button navigates to Home', (WidgetTester tester) async {
    await tester.pumpWidget(const CinemaApp());

    await tester.tap(find.text('Login'));
    await _pumpRoute(tester);

    expect(find.text('Find your next movie night'), findsOneWidget);
    expect(find.byKey(const Key('movieSearchField')), findsOneWidget);
  });

  testWidgets('Home renders movie titles from mock data', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);
    await _scrollHomeTo(tester, find.text(mockMovies[1].title));

    expect(find.text(mockMovies.first.title), findsWidgets);
    expect(find.text(mockMovies[1].title), findsOneWidget);
  });

  testWidgets('Home local search filters movie list', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);

    await tester.enterText(find.byKey(const Key('movieSearchField')), 'iron');
    await tester.pump();
    await _scrollHomeTo(tester, find.text('Iron Horizon').first);

    expect(find.text('Iron Horizon'), findsWidgets);
    expect(find.text('Red Curtain'), findsNothing);
  });

  testWidgets('Tapping a movie opens Movie Detail', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);

    await tester.enterText(find.byKey(const Key('movieSearchField')), 'iron');
    await tester.pump();
    await _scrollHomeTo(tester, find.text('Iron Horizon').last);
    await tester.tap(find.text('Iron Horizon').last);
    await _pumpRoute(tester);

    expect(find.text('Iron Horizon'), findsWidgets);
    expect(find.text('Select Showtime'), findsOneWidget);
  });

  testWidgets('Movie Detail renders selected movie title', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);

    await tester.enterText(
      find.byKey(const Key('movieSearchField')),
      'midnight',
    );
    await tester.pump();
    await _scrollHomeTo(tester, find.text('Midnight Reel').last);
    await tester.tap(find.text('Midnight Reel').last);
    await _pumpRoute(tester);

    expect(find.text('Midnight Reel'), findsWidgets);
    expect(find.text('Mystery, Drama'), findsWidgets);
  });

  testWidgets('Booking flow still reaches Showtime from Movie Detail', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);

    await tester.tap(find.text('View Details'));
    await _pumpRoute(tester);
    await tester.ensureVisible(find.text('Select Showtime'));
    await tester.pump();
    await tester.tap(find.text('Select Showtime'));
    await _pumpRoute(tester);

    expect(find.text('Select Showtime'), findsWidgets);
  });

  testWidgets('Seat Selection flow handles selecting available seats', (WidgetTester tester) async {
    await _openHome(tester);

    await tester.tap(find.text('View Details'));
    await _pumpRoute(tester);
    await tester.ensureVisible(find.text('Select Showtime'));
    await tester.pump();
    await tester.tap(find.text('Select Showtime'));
    await _pumpRoute(tester);

    // Tap first showtime to go to seats
    await tester.tap(find.textContaining('Room A'));
    await tester.pump(); // state update for selection
    await tester.tap(find.text('Continue to Seats'));
    await _pumpRoute(tester);

    expect(find.text('0 seat(s)'), findsOneWidget);

    // Continue should be disabled
    final continueBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton).last);
    expect(continueBtn.onPressed, isNull);

    // Tap seat 1 in Row A (Available)
    await tester.tap(find.text('1').first);
    await tester.pump();

    // Now 1 seat is selected
    expect(find.text('1 seat(s)'), findsOneWidget);
    expect(find.text('\$15.00'), findsWidgets); // Price for mock showtime 101

    // Tap again to deselect
    await tester.tap(find.text('1').first);
    await tester.pump();
    expect(find.text('0 seat(s)'), findsOneWidget);
  });

  testWidgets('Booking Summary receives draft and renders details', (WidgetTester tester) async {
    await _openHome(tester);

    await tester.tap(find.text('View Details'));
    await _pumpRoute(tester);
    await tester.ensureVisible(find.text('Select Showtime'));
    await tester.pump();
    await tester.tap(find.text('Select Showtime'));
    await _pumpRoute(tester);

    await tester.tap(find.textContaining('Room A'));
    await tester.pump();
    await tester.tap(find.text('Continue to Seats'));
    await _pumpRoute(tester);

    // Select two seats
    await tester.tap(find.text('4').first);
    await tester.pump();
    await tester.tap(find.text('5').first);
    await tester.pump();

    // Proceed to booking summary
    await tester.tap(find.text('Continue'));
    await _pumpRoute(tester);

    expect(find.text('Booking Summary'), findsWidgets);
    expect(find.text('2 Ticket(s)'), findsOneWidget);
    expect(find.text('\$30.00'), findsWidgets); // 15.00 * 2 = 30.00
    
    // Tap Confirm Booking
    await tester.scrollUntilVisible(
      find.text('Confirm Booking'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Confirm Booking'));
    await _pumpRoute(tester);
    
    // Verify it navigates somewhere (e.g. payment placeholder or error)
    // The previous implementation went to AppRoutes.payment, which might just be a placeholder
  });

  testWidgets('My Bookings renders backend-aligned bookings and navigates to Detail', (WidgetTester tester) async {
    // We can navigate to my bookings if there is a button, or just pump it directly for the test.
    // For now, let's just use CinemaApp and push the route directly using a Navigator key, 
    // or just pump the widget directly wrapped in a MaterialApp.
    // However, CinemaApp has the routing setup. Let's just pump the screen directly for isolation.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      routes: {
        '/': (_) => const MyBookingsScreen(),
        AppRoutes.bookingDetail: (_) => const BookingDetailScreen(),
      },
    ));

    expect(find.text('My Bookings'), findsWidgets);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    // Active tab has pending and confirmed bookings
    expect(find.text('Code: BKG-XYZ-101'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);

    // Tap first booking to open Booking Detail
    await tester.tap(find.text('Code: BKG-XYZ-101'));
    await _pumpRoute(tester);

    expect(find.text('Booking Detail'), findsWidgets);
    expect(find.text('Code: BKG-XYZ-101'), findsWidgets);
    expect(find.text('Cancel Booking'), findsOneWidget); // Pending bookings can be cancelled

    // Back to My Bookings
    await tester.pageBack();
    await _pumpRoute(tester);

    // Switch to History tab by swiping
    await tester.drag(find.text('Code: BKG-XYZ-101').first, const Offset(-500.0, 0.0));
    await tester.pumpAndSettle(); // ensure tab animation finishes

    expect(find.text('Code: BKG-LMN-303'), findsOneWidget); // Cancelled
    expect(find.text('Cancelled'), findsOneWidget);

    // Tap cancelled booking
    await tester.tap(find.text('Code: BKG-LMN-303'));
    await _pumpRoute(tester);

    expect(find.text('Code: BKG-LMN-303'), findsWidgets);
    expect(find.text('Cancel Booking'), findsNothing); // Cancelled booking shouldn't have cancel button
  });
}

Future<void> _openHome(WidgetTester tester) async {
  await tester.pumpWidget(const CinemaApp());
  await tester.tap(find.text('Login'));
  await _pumpRoute(tester);
}

Future<void> _scrollHomeTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('homeScrollView')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
}

Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
