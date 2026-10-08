import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/features/auth/screens/forgot_password_screen.dart';
import 'package:cinema_fe/features/auth/screens/login_screen.dart';
import 'package:cinema_fe/features/auth/screens/register_screen.dart';
import 'package:cinema_fe/features/auth/screens/reset_password_screen.dart';
import 'package:cinema_fe/features/auth/screens/verify_email_screen.dart';
import 'package:cinema_fe/features/auth/verify_email_arguments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/test_app.dart';

void main() {
  testWidgets('Login back returns to the existing Home route', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await pumpRoute(tester);
    final homeContext = tester.element(find.text('Find your next movie night'));
    await tester.tap(find.text('Sign in').first);
    await pumpRoute(tester);
    expect(find.text('Home'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await pumpRoute(tester);
    expect(find.text('Find your next movie night'), findsOneWidget);
    expect(
      tester.element(find.text('Find your next movie night')),
      same(homeContext),
    );
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('Login back opens Home when Login is the initial route', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.login));
    await pumpRoute(tester);
    await tester.tap(find.byTooltip('Back to home'));
    await pumpRoute(tester);
    expect(find.text('Find your next movie night'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    final context = tester.element(find.text('Find your next movie night'));
    expect(Navigator.of(context).canPop(), isFalse);
  });

  testWidgets('Auth actions stay reachable on small and landscape screens', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final repository = FakeAuthRepository();
    final pages = [
      (LoginScreen(authRepository: repository), null, 'Sign in'),
      (RegisterScreen(authRepository: repository), null, 'Create account'),
      (ForgotPasswordScreen(authRepository: repository), null, 'Continue'),
      (
        VerifyEmailScreen(authRepository: repository),
        const VerifyEmailArguments(
          email: 'jane@example.com',
          password: 'Secret123',
        ),
        'Verify email',
      ),
      (
        ResetPasswordScreen(authRepository: repository),
        'jane@example.com',
        'Reset password',
      ),
    ];
    for (final variant in [
      (const Size(375, 667), 1.0),
      (const Size(390, 844), 1.6),
      (const Size(844, 390), 1.0),
    ]) {
      final size = variant.$1;
      tester.view.physicalSize = size;
      for (final page in pages) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(variant.$2)),
              child: child!,
            ),
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              settings: RouteSettings(arguments: page.$2),
              builder: (_) => page.$1,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.widgetWithText(ElevatedButton, page.$3);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (size == const Size(375, 667)) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          expect(action.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('Forgot password submits email, reset OTP and new password', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(
      buildTestApp(
        authRepository: repository,
        initialRoute: AppRoutes.forgotPassword,
      ),
    );
    await pumpRoute(tester);
    await tester.enterText(find.byType(TextFormField), 'jane@example.com');
    final send = find.widgetWithText(ElevatedButton, 'Continue');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await pumpRoute(tester);
    expect(repository.forgotPasswordEmail, 'jane@example.com');
    expect(find.text('Code sent to jane@example.com'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Verification code'),
      '123456',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'NewSecret123',
    );
    final reset = find.widgetWithText(ElevatedButton, 'Reset password');
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await pumpRoute(tester);
    expect(repository.resetOtp, '123456');
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets(
    'Required marks are visible before typing and yield to password eye',
    (tester) async {
      await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.register));
      await pumpRoute(tester);
      expect(find.text('*'), findsNWidgets(3));
      expect(find.byTooltip('Show password'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'Secret123',
      );
      await tester.pump();
      expect(find.text('*'), findsNWidgets(2));
      expect(find.byTooltip('Show password'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isFalse,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        '',
      );
      await tester.pump();
      expect(find.text('*'), findsNWidgets(3));
      expect(find.byTooltip('Show password'), findsNothing);
    },
  );
}
