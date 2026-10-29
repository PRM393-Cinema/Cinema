import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/test_app.dart';

Finder _field(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(TextFormField),
);

Future<void> _openProfile(WidgetTester tester, FakeAuthRepository auth) async {
  tester.view.physicalSize = const Size(1280, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    buildTestApp(
      authenticated: true,
      authRepository: auth,
      initialRoute: AppRoutes.profile,
    ),
  );
  await pumpRoute(tester);
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('Customers edit their name and phone', (tester) async {
    final auth = FakeAuthRepository();
    await _openProfile(tester, auth);

    await tester.tap(find.byKey(const Key('editProfile')));
    await pumpRoute(tester);
    await tester.enterText(_field('profileNameField'), '');
    await tester.enterText(_field('profilePhoneField'), 'call me');
    await tester.tap(find.byKey(const Key('saveProfile')));
    await pumpRoute(tester);
    expect(find.text('Full name is required.'), findsOneWidget);
    expect(auth.profileUpdates, isEmpty);

    await tester.enterText(_field('profileNameField'), ' Tran Thi Moi ');
    await tester.enterText(_field('profilePhoneField'), '0912 345 678');
    await tester.tap(find.byKey(const Key('saveProfile')));
    await pumpRoute(tester);

    expect(auth.profileUpdates.single, (
      fullName: 'Tran Thi Moi',
      phone: '0912 345 678',
    ));
    expect(find.text('Profile saved.'), findsOneWidget);
    expect(find.text('Tran Thi Moi'), findsWidgets);
    expect(find.text('0912 345 678'), findsOneWidget);
  });

  testWidgets('Changing the password needs the current one', (tester) async {
    final auth = FakeAuthRepository();
    await _openProfile(tester, auth);

    await tester.tap(find.byKey(const Key('changePassword')));
    await pumpRoute(tester);
    await tester.enterText(_field('currentPasswordField'), 'Wrong@123');
    await tester.enterText(_field('newPasswordField'), 'Newer@123');
    await tester.enterText(_field('confirmPasswordField'), 'Newer@124');
    await tester.tap(find.byKey(const Key('savePassword')));
    await pumpRoute(tester);
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(auth.passwordChanges, isEmpty);

    await tester.enterText(_field('confirmPasswordField'), 'Newer@123');
    await tester.tap(find.byKey(const Key('savePassword')));
    await pumpRoute(tester);
    expect(find.text('Current password is incorrect.'), findsOneWidget);

    await tester.enterText(_field('currentPasswordField'), 'Secret@123');
    await tester.tap(find.byKey(const Key('savePassword')));
    await pumpRoute(tester);
    expect(auth.currentPassword, 'Newer@123');
    expect(find.byKey(const Key('savePassword')), findsNothing);
    expect(
      find.text('Password changed. Other devices were signed out.'),
      findsOneWidget,
    );
  });

  testWidgets('A forgotten current password goes to the email code flow', (
    tester,
  ) async {
    await _openProfile(tester, FakeAuthRepository());

    await tester.tap(find.byKey(const Key('changePassword')));
    await pumpRoute(tester);
    await tester.tap(find.byKey(const Key('forgotCurrentPassword')));
    await pumpRoute(tester);

    expect(find.byKey(const Key('savePassword')), findsNothing);
    expect(
      find.textContaining('send a verification code to your email'),
      findsOneWidget,
    );
  });
}
