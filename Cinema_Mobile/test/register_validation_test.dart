import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/test_app.dart';

void main() {
  testWidgets('Sign up shows each mistake and sends nothing until fixed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = FakeAuthRepository();
    await tester.pumpWidget(
      buildTestApp(authRepository: auth, initialRoute: AppRoutes.register),
    );
    await pumpRoute(tester);

    Future<void> fill(String key, String text) => tester.enterText(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextFormField),
      ),
      text,
    );
    Future<void> submit() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.widgetWithText(AppButton, 'Create account'));
      await pumpRoute(tester);
    }

    await submit();
    for (final message in [
      'Full name is required.',
      'Email is required.',
      'Password is required.',
      'Please enter the password again.',
    ]) {
      expect(find.text(message), findsOneWidget, reason: message);
    }

    await fill('registerFullNameField', 'Jane Customer');
    await fill('registerEmailField', 'jane@example');
    await fill('registerPhoneField', '+++');
    await fill('registerPasswordField', '12345');
    await fill('registerConfirmPasswordField', '12345');
    await submit();
    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    expect(find.text('Phone number must have 8 to 15 digits.'), findsOneWidget);
    expect(
      find.text('Password must be at least 6 characters.'),
      findsOneWidget,
    );

    await fill('registerEmailField', 'jane@example.com');
    await fill('registerPhoneField', '0901 234 567');
    await fill('registerPasswordField', 'Secret123');
    await fill('registerConfirmPasswordField', 'Secret12');
    await submit();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(auth.registerCalls, 0);

    await fill('registerConfirmPasswordField', 'Secret123');
    await submit();
    expect(auth.registerCalls, 1);
    expect(find.text('Verify your email'), findsOneWidget);
  });

  testWidgets('Sign in checks the email before calling the server', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.login));
    await pumpRoute(tester);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('loginEmailField')),
        matching: find.byType(TextFormField),
      ),
      'a b@test.local',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.widgetWithText(AppButton, 'Sign in'));
    await pumpRoute(tester);

    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });
}
