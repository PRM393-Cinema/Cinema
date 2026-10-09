import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/core/session/session_state.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/core/widgets/app_button.dart';
import 'package:cinema_fe/data/repositories/auth_repository.dart';
import 'package:cinema_fe/features/auth/screens/login_screen.dart';
import 'package:cinema_fe/features/auth/screens/verify_email_screen.dart';
import 'package:cinema_fe/features/auth/verify_email_arguments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  testWidgets('App without session opens Home', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await pumpRoute(tester);

    expect(find.text('Step Into CosmoQ Cinema'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget); // AppBar action
  });

  testWidgets('Sign in action opens Login', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await pumpRoute(tester);
    await tester.tap(find.text('Sign in').first);
    await pumpRoute(tester);

    expect(find.byKey(const Key('loginTitle')), findsOneWidget);
  });

  testWidgets('Login loading state works', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(delay: const Duration(seconds: 1)),
      ),
    );
    await pumpRoute(tester);

    await tester.tap(find.text('Sign in').first);
    await pumpRoute(tester);
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

  testWidgets('Successful fake login navigates to Home with the user', (
    WidgetTester tester,
  ) async {
    final session = SessionState();
    await tester.pumpWidget(buildTestApp(session: session));
    await pumpRoute(tester);

    await _loginToHome(tester);

    expect(find.text('Step Into CosmoQ Cinema'), findsOneWidget);
    expect(find.byKey(const Key('movieSearchField')), findsOneWidget);
    expect(session.isAuthenticated, isTrue);
    expect(session.user?.userId, customerUser.userId);
    expect(find.byTooltip('My bookings'), findsOneWidget);
  });

  testWidgets('Failed fake login shows error and stays on Login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          loginErrorMessage: 'Bad credentials',
        ),
      ),
    );
    await pumpRoute(tester);

    await tester.tap(find.text('Sign in').first);
    await pumpRoute(tester);
    await _enterLoginCredentials(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton).first);
    await tester.pump();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(find.byKey(const Key('loginTitle')), findsOneWidget);
    expect(find.text('Find your next movie night'), findsNothing);
  });

  testWidgets('Register loading state works', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(delay: const Duration(seconds: 1)),
        initialRoute: AppRoutes.register,
      ),
    );

    await _enterRegisterDetails(tester);
    await tester.ensureVisible(find.byType(AppButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton).first);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('Register success navigates to Verify Email with email', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.register));

    await _enterRegisterDetails(tester);
    await tester.ensureVisible(find.byType(AppButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton).first);
    await pumpRoute(tester);

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Code sent to jane@example.com'), findsOneWidget);
  });

  testWidgets('Register failure displays error and stays on Register', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        authRepository: FakeAuthRepository(
          registerErrorMessage: 'Email already registered.',
        ),
        initialRoute: AppRoutes.register,
      ),
    );

    await _enterRegisterDetails(tester, email: 'taken@example.com');
    await tester.ensureVisible(find.byType(AppButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton).first);
    await tester.pump();

    expect(find.text('This email is already registered.'), findsOneWidget);
    expect(find.byKey(const Key('registerTitle')), findsOneWidget);
  });

  testWidgets('Verify Email success navigates to Login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_verifyEmailTestApp());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Verification code'),
      '123456',
    );
    await tester.ensureVisible(find.byType(AppButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await pumpRoute(tester);

    expect(find.byKey(const Key('loginTitle')), findsOneWidget);
  });

  testWidgets('Invalid OTP displays error on Verify Email', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _verifyEmailTestApp(
        authRepository: FakeAuthRepository(verifyErrorMessage: 'OTP invalid'),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Verification code'),
      '000000',
    );
    await tester.ensureVisible(find.byType(AppButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton).first);
    await tester.pump();

    expect(find.text('Invalid or expired verification code.'), findsOneWidget);
    expect(find.text('Verify your email'), findsOneWidget);
  });

  testWidgets('Home renders movies from the API', (WidgetTester tester) async {
    await _openHome(tester);
    await scrollHomeTo(tester, find.text(movieFixtures[1].title));

    expect(find.text(movieFixtures.first.title), findsWidgets);
    expect(find.text(movieFixtures[1].title), findsOneWidget);
  });

  testWidgets('Home shows an error with retry when movies cannot load', (
    WidgetTester tester,
  ) async {
    final catalog = FakeCatalogRepository(
      moviesErrorMessage: 'Unable to connect to the server. Please try again.',
    );
    await tester.pumpWidget(buildTestApp(catalogRepository: catalog));
    await pumpRoute(tester);

    expect(find.text('Unable to load movies'), findsOneWidget);

    catalog.moviesErrorMessage = null;
    await tester.tap(find.text('Retry'));
    await pumpRoute(tester);

    expect(find.text('Unable to load movies'), findsNothing);
    expect(find.text(movieFixtures.first.title), findsWidgets);
  });

  testWidgets('Home local search filters movie list', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);

    await tester.enterText(find.byKey(const Key('movieSearchField')), 'inter');
    await tester.pump();
    await scrollHomeTo(tester, find.text('Interstellar').first);

    expect(find.text('Interstellar'), findsWidgets);
    expect(find.text('Oppenheimer'), findsNothing);
  });

  testWidgets('Tapping a movie opens Movie Detail', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);

    await tester.enterText(find.byKey(const Key('movieSearchField')), 'inter');
    await tester.pump();
    await scrollHomeTo(tester, find.text('Interstellar').last);
    await tester.tap(find.text('Interstellar').last);
    await pumpRoute(tester);

    expect(find.text('Interstellar'), findsWidgets);
    expect(find.text('Showtimes'), findsOneWidget);
    expect(find.text('Continue to Seats'), findsOneWidget);
  });

  testWidgets('Movie Detail renders selected movie title', (
    WidgetTester tester,
  ) async {
    await _openHome(tester);

    await tester.enterText(find.byKey(const Key('movieSearchField')), 'oppen');
    await tester.pump();
    await scrollHomeTo(tester, find.text('Oppenheimer').last);
    await tester.tap(find.text('Oppenheimer').last);
    await pumpRoute(tester);

    expect(find.text('Oppenheimer'), findsWidgets);
    expect(find.text('Biography, Drama'), findsWidgets);
  });

  testWidgets('Movie Detail lists the upcoming showtimes', (
    WidgetTester tester,
  ) async {
    await _openHome(tester, authenticated: true);
    await _openMovieDetail(tester);

    expect(find.text('Showtimes'), findsOneWidget);
    expect(find.textContaining('Tomorrow'), findsOneWidget);
    expect(find.text('7:30 PM'), findsOneWidget);
    expect(find.text('Room 1'), findsOneWidget);
    expect(find.text(formatVnd(90000)), findsOneWidget);

    // Nothing chosen yet: the way to the seats is disabled.
    final continueButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue to Seats'),
    );
    expect(continueButton.onPressed, isNull);

    await tester.ensureVisible(find.text('7:30 PM'));
    await tester.pump();
    await tester.tap(find.text('7:30 PM'));
    await tester.pump();

    expect(find.textContaining('7:30 PM • Room 1'), findsOneWidget);
    expect(find.text('${formatVnd(90000)} / seat'), findsOneWidget);
  });

  testWidgets('Guest attempting protected action goes to Login', (
    WidgetTester tester,
  ) async {
    await _openHome(tester, authenticated: false);
    await _openMovieDetail(tester);

    await tester.ensureVisible(find.text('Room 1'));
    await tester.pump();
    await tester.tap(find.text('Room 1'));
    await tester.pump();
    await tester.tap(find.text('Continue to Seats'));
    await pumpRoute(tester);

    expect(find.byKey(const Key('loginTitle')), findsOneWidget);
  });
}

Widget _verifyEmailTestApp({AuthRepository? authRepository}) {
  final repository = authRepository ?? FakeAuthRepository();
  return SessionProvider(
    sessionState: SessionState()..setGuest(),
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.login) {
          return MaterialPageRoute(
            builder: (_) => LoginScreen(authRepository: repository),
          );
        }

        return MaterialPageRoute(
          settings: const RouteSettings(
            arguments: VerifyEmailArguments(
              email: 'jane@example.com',
              password: 'Secret123',
            ),
          ),
          builder: (_) => VerifyEmailScreen(authRepository: repository),
        );
      },
    ),
  );
}

Future<void> _openHome(WidgetTester tester, {bool authenticated = true}) async {
  await tester.pumpWidget(buildTestApp(authenticated: authenticated));
  await pumpRoute(tester);
}

Future<void> _openMovieDetail(WidgetTester tester) async {
  await scrollHomeTo(tester, find.text('View Details').first);
  await tester.tap(find.text('View Details').first);
  await pumpRoute(tester);
}

Future<void> _loginToHome(WidgetTester tester) async {
  await tester.tap(find.text('Sign in').first);
  await pumpRoute(tester);
  await _enterLoginCredentials(tester);
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(AppButton).first);
  await tester.pump();
  expect(find.text('Signed in!'), findsOneWidget);
  await tester.pump(const Duration(seconds: 3));
  await pumpRoute(tester);
}

Future<void> _enterLoginCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('loginEmailField')),
      matching: find.byType(TextFormField),
    ),
    'khachhang1@gmail.com',
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('loginPasswordField')),
      matching: find.byType(TextFormField),
    ),
    '123456',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> _enterRegisterDetails(
  WidgetTester tester, {
  String email = 'jane@example.com',
}) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('registerFullNameField')),
      matching: find.byType(TextFormField),
    ),
    'Jane Customer',
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('registerEmailField')),
      matching: find.byType(TextFormField),
    ),
    email,
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('registerPhoneField')),
      matching: find.byType(TextFormField),
    ),
    '0123456789',
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('registerPasswordField')),
      matching: find.byType(TextFormField),
    ),
    'Secret123',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}
