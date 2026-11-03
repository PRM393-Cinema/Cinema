import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/paged_result.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

class _People extends FakeAuthRepository {
  final calls = <(int, String?, String?, bool?)>[];
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
    calls.add((page, keyword, role, enabled));
    return PagedResult(
      items: [customerUser],
      pageNumber: page,
      totalPages: 2,
      totalCount: 11,
    );
  }

  @override
  Future<AuthUser> getUser(int id) async => customerUser;
}

void main() {
  for (final theme in ['dark', 'light']) {
    for (final width in [375.0, 900.0, 1440.0]) {
      for (final section in ['Promotions', 'Members', 'Accounts']) {
        testWidgets('$section web catalog $theme at $width', (tester) async {
          FlutterSecureStorage.setMockInitialValues({
            'appearance.theme': theme,
          });
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final auth = _People();
          final now = DateTime.now();
          final service = StaffService(
            client: ApiClient(
              httpClient: MockClient((request) async {
                final Object response = request.url.path.contains('promotions')
                    ? [
                        for (var id = 1; id <= 4; id++)
                          {
                            'id': id,
                            'name': 'Offer $id',
                            'code': 'PROMO$id',
                            'discountType': 'PERCENT',
                            'discountValue': 10,
                            'active': id != 4,
                            'startsAt': id == 2
                                ? now
                                      .add(const Duration(days: 1))
                                      .toIso8601String()
                                : null,
                            'endsAt': id == 3
                                ? now
                                      .subtract(const Duration(days: 1))
                                      .toIso8601String()
                                : null,
                          },
                      ]
                    : request.url.path.endsWith('/accounts')
                    ? [
                        {
                          'userId': 3,
                          'points': 120,
                          'tier': 'VIP',
                          'lifetimeSpend': 2500000,
                          'earnRatePercent': 7,
                        },
                      ]
                    : {
                        'userId': 3,
                        'points': 120,
                        'tier': 'VIP',
                        'lifetimeSpend': 2500000,
                        'earnRatePercent': 7,
                      };
                return http.Response(
                  jsonEncode(response),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }),
            ),
          );
          final route = switch (section) {
            'Promotions' => AppRoutes.adminPromotions,
            'Members' => AppRoutes.adminMembers,
            _ => AppRoutes.adminUsers,
          };
          await tester.pumpWidget(
            buildAdminTestApp(
              authenticated: true,
              user: AuthUser.fromJson({
                ...customerUser.toJson(),
                'roles': ['ROLE_ADMIN'],
              }),
              authRepository: auth,
              staffService: service,
              initialRoute: route,
            ),
          );
          await pumpRoute(tester);
          expect(
            find.byKey(Key('admin${section}Table')),
            width >= 900 ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
          if (section == 'Promotions') {
            for (final status in ['Running', 'Scheduled', 'Ended', 'Stopped']) {
              await tester.tap(find.byKey(const Key('promotionStatusFilter')));
              await tester.pumpAndSettle();
              await tester.tap(find.text(status).last);
              await tester.pumpAndSettle();
              expect(find.text('1 of 4 promotions'), findsOneWidget);
            }
            await tester.enterText(
              find.descendant(
                of: find.byKey(const Key('promotionSearch')),
                matching: find.byType(EditableText),
              ),
              'missing',
            );
            await tester.pumpAndSettle();
            expect(find.text('No matching promotions.'), findsOneWidget);
          } else {
            if (section == 'Accounts') {
              await tester.tap(find.byKey(const Key('accountRoleFilter')));
              await pumpRoute(tester);
              await tester.tap(find.text('Staff').last);
              await pumpRoute(tester);
              expect(auth.calls.last.$3, 'ROLE_STAFF');
              await tester.tap(find.byKey(const Key('accountStatusFilter')));
              await pumpRoute(tester);
              await tester.tap(find.text('Locked').last);
              await pumpRoute(tester);
              expect(auth.calls.last.$4, isFalse);
            }
            await tester.ensureVisible(find.text('Next'));
            await tester.tap(find.text('Next'));
            await pumpRoute(tester);
            expect(auth.calls.last.$1, 2);
            if (section == 'Members') {
              expect(auth.calls.last.$3, 'ROLE_CUSTOMER');
              final member = find.byKey(const ValueKey('member-3'));
              await tester.ensureVisible(member);
              await tester.tap(member);
              await pumpRoute(tester);
              expect(find.text('120 points'), findsOneWidget);
            } else {
              final manage = width >= 900
                  ? find.byKey(const ValueKey('manageAccount-3'))
                  : find.text(customerUser.displayName);
              await tester.ensureVisible(manage);
              await tester.tap(manage);
              await pumpRoute(tester);
              expect(find.text('Account details'), findsOneWidget);
            }
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
