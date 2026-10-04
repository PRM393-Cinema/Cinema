import 'package:cinema_fe/app/app.dart';
import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/core/network/api_exception.dart';
import 'package:cinema_fe/data/mock/mock_movies.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/repositories/auth_repository.dart';
import 'package:cinema_fe/features/booking/screens/booking_detail_screen.dart';
import 'package:cinema_fe/features/booking/screens/my_bookings_screen.dart';
import 'package:cinema_fe/core/session/session_state.dart';
import 'package:cinema_fe/core/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App without session opens Home', (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithSession(_testApp(authenticated: false), authenticated: false));

    expect(find.text('Find your next movie night'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget); // AppBar action
  });

  testWidgets('Sign in action opens Login', (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithSession(_testApp(authenticated: false), authenticated: false));
    await tester.tap(find.text('Sign in').first);
    await _pumpRoute(tester);

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Login loading state works', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrapWithSession(_testApp(authRepository: _FakeAuthRepository.delayed())),
    );

    await tester.tap(find.text('Sign in').first);
    await _pumpRoute(tester);
    await _enterLoginCredentials(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton).first);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final loginButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton).first,
    );
    expect(loginButton.onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('Successful fake login navigates to Home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrapWithSession(_testApp()));

    await _loginToHome(tester);

    expect(find.text('Find your next movie night'), findsOneWidget);
    expect(find.byKey(const Key('movieSearchField')), findsOneWidget);
  });

  testWidgets('Failed fake login shows error and stays on Login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithSession(_testApp(authRepository: _FakeAuthRepository.failure('Bad credentials'))),
    );

    await tester.tap(find.text('Sign in').first);
    await _pumpRoute(tester);
    await _enterLoginCredentials(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton).first);
    await tester.pump();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Find your next movie night'), findsNothing);
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
    await _openHome(tester, authenticated: true);

    await _scrollHomeTo(tester, find.text('View Details').first);
    await tester.tap(find.text('View Details').first);
    await _pumpRoute(tester);
    await tester.ensureVisible(find.text('Select Showtime'));
    await tester.pump();
    await tester.tap(find.text('Select Showtime'));
    await _pumpRoute(tester);

    expect(find.text('Select Showtime'), findsWidgets);
  });

  testWidgets('Guest attempting protected action gets Sign in required prompt', (WidgetTester tester) async {
    await _openHome(tester, authenticated: false);
    
    // Tap a movie
    await _scrollHomeTo(tester, find.text('View Details').first);
    await tester.tap(find.text('View Details').first);
    await _pumpRoute(tester);

    await tester.ensureVisible(find.text('Select Showtime'));
    await tester.pump();
    await tester.tap(find.text('Select Showtime'));
    await _pumpRoute(tester);

    // On showtime screen, tap a room
    await tester.tap(find.textContaining('Room A').first);
    await tester.pump();
    await tester.tap(find.text('Continue to Seats'));
    await tester.pump();

    expect(find.text('Sign in required'), findsOneWidget);
    expect(find.text('Please sign in to continue with this action.'), findsOneWidget);
  });

  testWidgets('Seat Selection flow handles selecting available seats', (
    WidgetTester tester,
  ) async {
    await _openHome(tester, authenticated: true);

    await _scrollHomeTo(tester, find.text('View Details').first);
    await tester.tap(find.text('View Details').first);
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
    final continueBtn = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton).last,
    );
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

  testWidgets('Booking Summary receives draft and renders details', (
    WidgetTester tester,
  ) async {
    await _openHome(tester, authenticated: true);

    await _scrollHomeTo(tester, find.text('View Details').first);
    await tester.tap(find.text('View Details').first);
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

  testWidgets(
    'My Bookings renders backend-aligned bookings and navigates to Detail',
    (WidgetTester tester) async {
      // We can navigate to my bookings if there is a button, or just pump it directly for the test.
      // For now, let's just use CinemaApp and push the route directly using a Navigator key,
      // or just pump the widget directly wrapped in a MaterialApp.
      // However, CinemaApp has the routing setup. Let's just pump the screen directly for isolation.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          routes: {
            '/': (_) => const MyBookingsScreen(),
            AppRoutes.bookingDetail: (_) => const BookingDetailScreen(),
          },
        ),
      );

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
      expect(
        find.text('Cancel Booking'),
        findsOneWidget,
      ); // Pending bookings can be cancelled

      // Back to My Bookings
      await tester.pageBack();
      await _pumpRoute(tester);

      // Switch to History tab by swiping
      await tester.drag(
        find.text('Code: BKG-XYZ-101').first,
        const Offset(-500.0, 0.0),
      );
      await tester.pumpAndSettle(); // ensure tab animation finishes

      expect(find.text('Code: BKG-LMN-303'), findsOneWidget); // Cancelled
      expect(find.text('Cancelled'), findsOneWidget);

      // Tap cancelled booking
      await tester.tap(find.text('Code: BKG-LMN-303'));
      await _pumpRoute(tester);

      expect(find.text('Code: BKG-LMN-303'), findsWidgets);
      expect(
        find.text('Cancel Booking'),
        findsNothing,
      ); // Cancelled booking shouldn't have cancel button
    },
  );
}

CinemaApp _testApp({AuthRepository? authRepository, bool authenticated = false}) {
  final session = SessionState();
  if (authenticated) {
    session.setAuthenticated();
  } else {
    session.setGuest();
  }

  return CinemaApp(
    authRepository: authRepository ?? _FakeAuthRepository.success(),
    initialRoute: AppRoutes.home,
  );
}

Widget _wrapWithSession(Widget app, {bool authenticated = false}) {
  final session = SessionState();
  if (authenticated) {
    session.setAuthenticated();
  } else {
    session.setGuest();
  }
  return SessionProvider(
    sessionState: session,
    child: app,
  );
}

Future<void> _openHome(WidgetTester tester, {bool authenticated = true}) async {
  await tester.pumpWidget(_wrapWithSession(_testApp(authenticated: authenticated), authenticated: authenticated));
}

Future<void> _loginToHome(WidgetTester tester) async {
  await tester.tap(find.text('Sign in').first);
  await _pumpRoute(tester);
  await _enterLoginCredentials(tester);
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(AppButton).first);
  await _pumpRoute(tester);
}

Future<void> _enterLoginCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    'admin@cinema.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    '123456',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
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
  await tester.pumpAndSettle();
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository._({
    required this.response,
    this.errorMessage,
    this.delay = Duration.zero,
  });

  factory _FakeAuthRepository.success() {
    return _FakeAuthRepository._(response: _authResponseFixture);
  }

  factory _FakeAuthRepository.delayed() {
    return _FakeAuthRepository._(
      response: _authResponseFixture,
      delay: const Duration(seconds: 1),
    );
  }

  factory _FakeAuthRepository.failure(String message) {
    return _FakeAuthRepository._(
      response: _authResponseFixture,
      errorMessage: message,
    );
  }

  final AuthResponse response;
  final String? errorMessage;
  final Duration delay;

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (errorMessage != null) {
      throw ApiException(statusCode: 401, message: errorMessage!);
    }

    return response;
  }
}

final _authResponseFixture = AuthResponse(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  tokenType: 'Bearer',
  expiresAt: DateTime(2026, 10, 4, 12),
  user: AuthUser(
    userId: 1,
    email: 'admin@cinema.com',
    fullName: 'Admin',
    phone: null,
    enabled: true,
    emailVerified: true,
    createdAt: DateTime(2026, 10, 1),
    roles: const ['ROLE_ADMIN'],
  ),
);
