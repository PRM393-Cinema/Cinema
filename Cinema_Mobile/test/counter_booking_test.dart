import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/seat.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

final _staff = AuthUser.fromJson({
  ...customerUser.toJson(),
  'userId': 2,
  'roles': ['ROLE_STAFF'],
});

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('Staff pick a movie, a showtime and seats on the map', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final posts = <Map<String, Object?>>[];
    final service = StaffService(
      client: ApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'POST') {
            posts.add((jsonDecode(request.body) as Map).cast());
          }
          return http.Response(
            jsonEncode({
              'id': 77,
              'bookingCode': 'BK-COUNTER',
              'userId': 101,
              'showtimeId': 11,
              'status': 'PENDING',
              'totalAmount': 324000,
              'createdAt': DateTime.now().toIso8601String(),
              'seats': const [],
              'items': const [],
              'totalCount': 0,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );
    // Row A: standard seats (A2 taken); row B: sweetbox seats.
    final catalog = FakeCatalogRepository(
      showtimes: [
        showtimeFixture(
          seatPrices: const {
            'NORMAL': 90000,
            'VIP': 108000,
            'SWEETBOX': 117000,
          },
        ),
      ],
      seatMap: ShowtimeSeatsData.fromOccupied(
        seats: [
          for (final (index, (row, type)) in [
            ('A', 'NORMAL'),
            ('B', 'SWEETBOX'),
          ].indexed)
            for (var number = 1; number <= 4; number++)
              Seat(
                id: index * 4 + number,
                roomId: 1,
                row: row,
                number: number,
                type: type,
              ),
        ],
        occupiedSeatIds: const [2],
      ),
    );
    await tester.pumpWidget(
      buildAdminTestApp(
        authenticated: true,
        user: _staff,
        staffService: service,
        catalogRepository: catalog,
        initialRoute: AppRoutes.staffCreateBooking,
      ),
    );
    await pumpRoute(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Customer account ID'),
      '101',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Customer email'),
      'khach@test.local',
    );

    await tester.tap(find.byKey(const Key('bookingMovie')));
    await pumpRoute(tester);
    await tester.tap(find.text(inception.title).last);
    await pumpRoute(tester);
    await tester.tap(find.byKey(ValueKey('bookingShowtime-${inception.id}')));
    await pumpRoute(tester);
    await tester.tap(find.textContaining('Room 1 •').last);
    await pumpRoute(tester);

    // B1 brings its sweetbox pair B2; A2 is taken.
    await tester.tap(find.byKey(const ValueKey('counterSeat-B1')));
    await tester.tap(find.byKey(const ValueKey('counterSeat-A2')));
    await tester.tap(find.byKey(const ValueKey('counterSeat-A1')));
    await tester.pump();
    expect(
      find.text('3 seat(s) selected · ${formatVnd(324000)}'),
      findsOneWidget,
    );
    expect(find.text('${formatVnd(234000)} / pair'), findsOneWidget);

    // The busy button and the success dialog animate, so they never settle.
    await tester.tap(find.text('Create booking'));
    await pumpFrames(tester);
    await tester.tap(find.text('Confirm'));
    await pumpFrames(tester);

    final body = posts.single;
    expect(body['userId'], 101);
    expect(body['customerEmail'], 'khach@test.local');
    expect(body['showtimeId'], 11);
    expect(
      {for (final seat in body['seats'] as List) (seat as Map)['seatId']},
      {1, 5, 6},
    );
  });
}
