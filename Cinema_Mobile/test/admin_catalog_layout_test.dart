import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:cinema_fe/features/admin/widgets/admin_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  for (final width in [375.0, 1440.0]) {
    testWidgets('Catalog pager keeps server page callbacks at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pages = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPager(page: 1, totalPages: 2, onOpen: pages.add),
          ),
        ),
      );
      await tester.tap(find.text('Previous'));
      expect(pages, isEmpty);
      await tester.tap(find.text('Next'));
      expect(pages, [2]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPager(page: 2, totalPages: 2, onOpen: pages.add),
          ),
        ),
      );
      await tester.tap(find.text('Previous'));
      expect(pages, [2, 1]);
      await tester.tap(find.text('Next'));
      expect(pages, [2, 1]);
      expect(tester.takeException(), isNull);
    });
  }
  for (final theme in ['dark', 'light']) {
    for (final width in [375.0, 900.0, 1440.0]) {
      for (final kind in ['Movies', 'Rooms', 'Snacks']) {
        testWidgets('$kind catalog adapts at $width in $theme', (tester) async {
          FlutterSecureStorage.setMockInitialValues({
            'appearance.theme': theme,
          });
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final service = StaffService(
            client: ApiClient(
              httpClient: MockClient((request) async {
                final path = request.url.path;
                final Object body = path.contains('concessions')
                    ? [
                        {
                          'id': 1,
                          'name': 'Popcorn',
                          'description': 'Large popcorn for two',
                          'price': 85000,
                          'active': true,
                        },
                        {
                          'id': 2,
                          'name': 'Cola',
                          'description': 'Cold drink',
                          'price': 35000,
                          'active': false,
                        },
                      ]
                    : {
                        'items': path.contains('rooms')
                            ? [
                                {
                                  'id': 1,
                                  'name': 'Room 01 (IMAX)',
                                  'totalSeats': 54,
                                },
                              ]
                            : [
                                {
                                  'id': 1,
                                  'title': 'Inception',
                                  'genre': 'Sci-Fi',
                                  'durationMinutes': 148,
                                  'status': 'ACTIVE',
                                },
                              ],
                        'totalCount': 1,
                        'pageNumber': 1,
                        'totalPages': 1,
                      };
                return http.Response(
                  jsonEncode(body),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }),
            ),
          );
          final route = switch (kind) {
            'Movies' => AppRoutes.adminMovies,
            'Rooms' => AppRoutes.adminRooms,
            _ => AppRoutes.adminSnacks,
          };
          await tester.pumpWidget(
            buildAdminTestApp(
              authenticated: true,
              user: AuthUser.fromJson({
                ...customerUser.toJson(),
                'roles': ['ROLE_ADMIN'],
              }),
              staffService: service,
              initialRoute: route,
            ),
          );
          await pumpRoute(tester);
          expect(
            find.byKey(Key('admin${kind}Table')),
            width >= 900 ? findsOneWidget : findsNothing,
          );
          final addKey = switch (kind) {
            'Movies' => 'addMovieButton',
            'Rooms' => 'addRoomButton',
            _ => 'addSnackButton',
          };
          final searchKey = switch (kind) {
            'Movies' => 'movieSearchField',
            'Rooms' => 'roomSearchField',
            _ => 'snackSearchField',
          };
          final add = tester.getRect(find.byKey(Key(addKey)));
          final search = tester.getRect(find.byKey(Key(searchKey)));
          expect(add.width, lessThan(250));
          if (width >= 900) {
            expect(add.center.dy, closeTo(search.center.dy, 3));
            expect(add.left, greaterThan(search.right));
          }
          if (kind == 'Snacks') {
            await tester.enterText(
              find.descendant(
                of: find.byKey(const Key('snackSearchField')),
                matching: find.byType(EditableText),
              ),
              'Popcorn',
            );
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('adminSnack-1')), findsOneWidget);
            expect(find.text('Cola'), findsNothing);
            expect(find.text('1 of 2 items'), findsOneWidget);
            await tester.enterText(
              find.descendant(
                of: find.byKey(const Key('snackSearchField')),
                matching: find.byType(EditableText),
              ),
              '',
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('snackStatusFilter')));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Stopped').last);
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('adminSnack-1')), findsNothing);
            expect(find.byKey(const ValueKey('adminSnack-2')), findsOneWidget);
          }
          await tester.tap(find.byKey(Key(addKey)));
          await pumpRoute(tester);
          expect(find.byType(Dialog), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
