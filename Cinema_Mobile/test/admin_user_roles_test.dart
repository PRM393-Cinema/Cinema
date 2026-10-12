import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/widgets/app_button.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

final _admin = AuthUser.fromJson({
  ...customerUser.toJson(),
  'userId': 1,
  'roles': ['ROLE_ADMIN'],
});

void main() {
  testWidgets('Changing roles replaces the selection and saves one role', (
    tester,
  ) async {
    final repository = _AdminRepository();
    await tester.pumpWidget(
      buildTestApp(
        authRepository: repository,
        authenticated: true,
        user: _admin,
        initialRoute: AppRoutes.adminUser(customerUser.userId),
      ),
    );
    await pumpRoute(tester);

    expect(
      tester.widget<RadioGroup<String>>(_group).groupValue,
      'ROLE_CUSTOMER',
    );
    for (final role in ['Staff', 'Admin', 'Staff', 'Staff']) {
      await tester.ensureVisible(find.text(role));
      await tester.tap(find.text(role));
      await tester.pump();
    }
    expect(tester.widget<RadioGroup<String>>(_group).groupValue, 'ROLE_STAFF');

    await tester.ensureVisible(find.text('Save roles'));
    await tester.tap(find.text('Save roles'));
    await pumpRoute(tester);
    expect(repository.updatedRoles, ['ROLE_STAFF']);
    expect(find.byKey(const Key('topNotice')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Account roles updated.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await pumpRoute(tester);
  });

  testWidgets('Existing multiple roles require choosing one before saving', (
    tester,
  ) async {
    final repository = _AdminRepository(
      user: AuthUser.fromJson({
        ...customerUser.toJson(),
        'roles': ['ROLE_STAFF', 'ROLE_CUSTOMER'],
      }),
    );
    await tester.pumpWidget(
      buildTestApp(
        authRepository: repository,
        authenticated: true,
        user: _admin,
        initialRoute: AppRoutes.adminUser(customerUser.userId),
      ),
    );
    await pumpRoute(tester);

    expect(tester.widget<RadioGroup<String>>(_group).groupValue, isNull);
    final save = find.widgetWithText(AppButton, 'Save roles');
    expect(tester.widget<AppButton>(save).onPressed, isNull);
    await tester.ensureVisible(find.text('Staff'));
    await tester.tap(find.text('Staff'));
    await tester.pump();
    expect(tester.widget<RadioGroup<String>>(_group).groupValue, 'ROLE_STAFF');
    expect(tester.widget<AppButton>(save).onPressed, isNotNull);
  });

  testWidgets('Lock and unlock act directly and only show a top notice', (
    tester,
  ) async {
    final repository = _AdminRepository();
    await tester.pumpWidget(
      buildTestApp(
        authRepository: repository,
        authenticated: true,
        user: _admin,
        initialRoute: AppRoutes.adminUser(customerUser.userId),
      ),
    );
    await pumpRoute(tester);
    await tester.scrollUntilVisible(
      find.text('Lock account'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lock account'));
    await pumpRoute(tester);
    expect(repository.updatedEnabled, isFalse);
    expect(find.text('Account locked.'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Cancel'), findsNothing);

    await tester.ensureVisible(find.text('Unlock account'));
    await tester.tap(find.text('Unlock account'));
    await pumpRoute(tester);
    expect(repository.updatedEnabled, isTrue);
    expect(find.text('Account unlocked.'), findsOneWidget);
    expect(find.text('Account locked.'), findsNothing);
    expect(find.byKey(const Key('topNotice')), findsOneWidget);
  });

  testWidgets('Admin cannot switch their own role', (tester) async {
    final user = AuthUser.fromJson({
      ..._admin.toJson(),
      'roles': ['ROLE_CUSTOMER', 'ROLE_ADMIN'],
    });
    await tester.pumpWidget(
      buildTestApp(
        authRepository: _AdminRepository(user: user),
        authenticated: true,
        user: user,
        initialRoute: AppRoutes.adminUser(user.userId),
      ),
    );
    await pumpRoute(tester);

    expect(tester.widget<RadioGroup<String>>(_group).groupValue, 'ROLE_ADMIN');
    expect(
      tester
          .widgetList<RadioListTile<String>>(find.byType(RadioListTile<String>))
          .every((tile) => tile.enabled == false),
      isTrue,
    );
    await tester.ensureVisible(find.text('Staff'));
    await tester.tap(find.text('Staff'));
    await tester.pump();
    expect(tester.widget<RadioGroup<String>>(_group).groupValue, 'ROLE_ADMIN');
  });

  testWidgets('Creating an account submits only the chosen role', (
    tester,
  ) async {
    final repository = _AdminRepository();
    await tester.pumpWidget(
      buildTestApp(
        authRepository: repository,
        authenticated: true,
        user: _admin,
        initialRoute: AppRoutes.adminCreateUser,
      ),
    );
    await pumpRoute(tester);

    expect(
      tester.widget<RadioGroup<String>>(_group).groupValue,
      'ROLE_CUSTOMER',
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'New Staff');
    await tester.enterText(fields.at(1), 'newstaff@example.com');
    await tester.enterText(fields.at(2), 'password123');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.text('Staff'));
    await tester.tap(find.text('Staff'));
    await tester.pump();
    expect(tester.widget<RadioGroup<String>>(_group).groupValue, 'ROLE_STAFF');

    final create = find.widgetWithText(AppButton, 'Create account');
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await pumpRoute(tester);
    expect(repository.createdRoles, ['ROLE_STAFF']);
    await tester.pump(const Duration(seconds: 3));
    await pumpRoute(tester);
  });
}

final _group = find.byType(RadioGroup<String>);

class _AdminRepository extends FakeAuthRepository {
  _AdminRepository({super.user});

  List<String>? updatedRoles;
  List<String>? createdRoles;
  bool? updatedEnabled;

  @override
  Future<AuthUser> updateUserStatus(int id, bool enabled) async {
    updatedEnabled = enabled;
    return AuthUser.fromJson({...user.toJson(), 'enabled': enabled});
  }

  @override
  Future<AuthUser> getUser(int id) async => user;

  @override
  Future<List<String>> roles() async => [
    'ROLE_ADMIN',
    'ROLE_STAFF',
    'ROLE_CUSTOMER',
  ];

  @override
  Future<AuthUser> updateUserRoles(int id, List<String> roles) async {
    updatedRoles = roles;
    return AuthUser.fromJson({...user.toJson(), 'roles': roles});
  }

  @override
  Future<AuthUser> createUser({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required List<String> roles,
  }) async {
    createdRoles = roles;
    return AuthUser.fromJson({...user.toJson(), 'roles': roles});
  }
}
