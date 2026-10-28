import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/models/concession.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

const _popcorn = ConcessionItem(id: 1, name: 'Popcorn (M)', price: 55000);
const _combo = ConcessionItem(
  id: 2,
  name: 'Combo Couple',
  price: 129000,
  description: '1 popcorn (L) + 2 drinks (L)',
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('A booking reads its snacks', () {
    final booking = Booking.fromJson({
      'id': 1,
      'bookingCode': 'BK-1',
      'showtimeId': 1,
      'status': 'PENDING',
      'totalAmount': 239000,
      'concessionsAmount': 149000,
      'createdAt': DateTime.now().toIso8601String(),
      'seats': const [],
      'concessions': [
        {'itemId': 1, 'name': 'Popcorn (M)', 'unitPrice': 55000, 'quantity': 2},
        {'itemId': 3, 'name': 'Drink (L)', 'unitPrice': 39000, 'quantity': 1},
      ],
    });
    expect(booking.concessionsAmount, 149000);
    expect(booking.concessions.first.amount, 110000);
    expect(booking.snacksText, '2 × Popcorn (M), 1 × Drink (L)');
  });

  testWidgets('Snacks picked on the summary are added to the booking', (
    tester,
  ) async {
    final bookings = FakeBookingRepository()..snacks = const [_popcorn, _combo];
    await tester.pumpWidget(
      buildTestApp(authenticated: true, bookingRepository: bookings),
    );
    await pumpRoute(tester);
    await scrollHomeTo(tester, find.text(inception.title).first);
    await tester.tap(find.text(inception.title).first);
    await pumpRoute(tester);
    await tester.tap(find.text('View details'));
    await pumpRoute(tester);
    await tester.ensureVisible(find.text('Room 1'));
    await tester.pump();
    await tester.tap(find.text('Room 1'));
    await tester.pump();
    await tester.tap(find.text('Continue to Seats'));
    await pumpRoute(tester);
    await tester.tap(find.text('1').last);
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await pumpRoute(tester);

    expect(find.text('Snacks & drinks'), findsOneWidget);
    for (final key in ['snackAdd-1', 'snackAdd-1', 'snackAdd-2']) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
    }
    await tester.ensureVisible(find.byKey(const ValueKey('snackRemove-1')));
    await tester.tap(find.byKey(const ValueKey('snackRemove-1')));
    await tester.pump();
    expect(find.text('1x Popcorn (M)'), findsOneWidget);
    expect(find.text('1x Combo Couple'), findsOneWidget);
    // One standard seat (90.000) + 55.000 + 129.000.
    expect(find.text(formatVnd(274000)), findsOneWidget);

    await tester.ensureVisible(find.text('Confirm Booking'));
    await tester.tap(find.text('Confirm Booking'));
    await pumpFrames(tester);
    expect(bookings.createCalls.single.concessions, {1: 1, 2: 1});
  });

  testWidgets('Admin adds a snack to the menu', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final posted = <Map<String, Object?>>[];
    final menu = <Map<String, Object?>>[
      {'id': 1, 'name': 'Popcorn (M)', 'price': 55000, 'active': true},
      {'id': 4, 'name': 'Old drink', 'price': 15000, 'active': false},
    ];
    final service = StaffService(
      client: ApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'POST') {
            final body = (jsonDecode(request.body) as Map)
                .cast<String, Object?>();
            posted.add(body);
            menu.add({...body, 'id': 9});
            return _json(menu.last);
          }
          return _json(menu);
        }),
      ),
    );
    await tester.pumpWidget(
      buildAdminTestApp(
        authenticated: true,
        user: AuthUser.fromJson({
          ...customerUser.toJson(),
          'roles': ['ROLE_ADMIN'],
        }),
        staffService: service,
        initialRoute: AppRoutes.adminSnacks,
      ),
    );
    await pumpRoute(tester);

    expect(find.text('Old drink'), findsOneWidget);
    expect(find.text('Stopped'), findsOneWidget);

    await tester.tap(find.text('Add item'));
    await pumpRoute(tester);
    Finder field(String key) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field('snackPriceField'), '500');
    await tester.tap(find.byKey(const Key('saveSnack')));
    await pumpRoute(tester);
    expect(find.text('Enter a name.'), findsOneWidget);
    expect(find.text('Enter 1,000 to 10,000,000.'), findsOneWidget);

    await tester.enterText(field('snackNameField'), 'Combo Solo');
    await tester.enterText(field('snackPriceField'), '85000');
    await tester.tap(find.byKey(const Key('saveSnack')));
    await pumpFrames(tester);
    expect(posted.single['name'], 'Combo Solo');
    expect(posted.single['price'], 85000);
    await pumpRoute(tester);
    expect(find.byKey(const ValueKey('adminSnack-9')), findsOneWidget);
  });
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
