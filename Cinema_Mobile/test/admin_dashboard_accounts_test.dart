import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/paged_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

final _admin = AuthUser.fromJson({
  ...customerUser.toJson(),
  'roles': ['ROLE_ADMIN'],
});

class _Accounts extends FakeAuthRepository {
  _Accounts({this.empty = false}) : super(user: _admin);
  final bool empty;

  @override
  Future<List<String>> roles() async => [
    'ROLE_ADMIN',
    'ROLE_STAFF',
    'ROLE_CUSTOMER',
  ];

  @override
  Future<PagedResult<AuthUser>> users({
    int page = 1,
    String? keyword,
    String? role,
    bool? enabled,
  }) async {
    final items = [
      if (!empty)
        for (var i = 1; i <= 3; i++)
          AuthUser.fromJson({
            ...customerUser.toJson(),
            'userId': i,
            'fullName': 'Account $i',
            'email': 'account$i@example.com',
            'enabled': i != 3,
          }),
    ].where((user) => enabled == null || user.enabled == enabled).toList();
    return PagedResult(
      items: items,
      pageNumber: 1,
      totalPages: 1,
      totalCount: items.length,
    );
  }

  @override
  Future<AuthUser> getUser(int id) async =>
      (await users()).items.firstWhere((user) => user.userId == id);
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await pumpRoute(tester);
}

void main() {
  for (final theme in ['dark', 'light']) {
    for (final width in [375.0, 1440.0]) {
      testWidgets('$theme account chart and preview at $width', (tester) async {
        final semantics = tester.ensureSemantics();
        FlutterSecureStorage.setMockInitialValues({'appearance.theme': theme});
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          buildAdminTestApp(
            authenticated: true,
            user: _admin,
            authRepository: _Accounts(),
            initialRoute: AppRoutes.adminDashboard,
          ),
        );
        await pumpRoute(tester);
        await _scrollTo(tester, find.byKey(const Key('accountStatusChart')));
        expect(find.text('67%'), findsOneWidget);
        expect(find.text('Active · 2'), findsOneWidget);
        expect(find.text('Locked · 1'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Active accounts: 2 of 3'),
          findsOneWidget,
        );
        semantics.dispose();
        if (width == 1440) {
          await _scrollTo(
            tester,
            find.byKey(const Key('dashboardAccountsTable')),
          );
          expect(find.byType(DataTable), findsOneWidget);
          await tester.ensureVisible(find.text('View account').first);
          await tester.tap(find.text('View account').first);
        } else {
          expect(find.byType(DataTable), findsNothing);
          await _scrollTo(tester, find.text('Account 1'));
          await tester.tap(find.text('Account 1'));
        }
        await pumpRoute(tester);
        expect(
          ModalRoute.of(tester.element(find.byType(Scaffold).last))
              ?.settings
              .name,
          AppRoutes.adminUser(1),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Empty account chart has no percentage or table', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      buildAdminTestApp(
        authenticated: true,
        user: _admin,
        authRepository: _Accounts(empty: true),
        initialRoute: AppRoutes.adminDashboard,
      ),
    );
    await pumpRoute(tester);
    await _scrollTo(tester, find.byKey(const Key('accountStatusChart')));
    expect(find.text('No accounts yet.'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    expect(find.byType(DataTable), findsNothing);
    await _scrollTo(tester, find.text('No accounts found.'));
    expect(tester.takeException(), isNull);
  });
}
