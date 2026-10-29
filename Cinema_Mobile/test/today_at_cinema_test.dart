import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fixtures.dart';
import 'support/test_app.dart';

final _staff = AuthUser.fromJson({
  ...customerUser.toJson(),
  'userId': 2,
  'roles': ['ROLE_STAFF'],
});

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('The dashboard shows today and the showtimes around now', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final checkedInAt = DateTime.now().subtract(const Duration(minutes: 40));

    await tester.pumpWidget(
      buildAdminTestApp(
        authenticated: true,
        user: _staff,
        staffService: _api(checkedInAt),
        initialRoute: AppRoutes.staffDashboard,
      ),
    );
    await pumpRoute(tester);

    Finder tile(String label, String value) => find.descendant(
      of: find
          .ancestor(of: find.text(label), matching: find.byType(Column))
          .first,
      matching: find.text(value),
    );
    expect(tile('Bookings today', '7'), findsOneWidget);
    expect(tile('Showtimes with bookings', '3 / 20'), findsOneWidget);
    expect(tile('Tickets for today’s shows', '40'), findsOneWidget);
    expect(tile('Checked in for today’s shows', '33'), findsOneWidget);

    // The cancelled show (9), the fourth finished (10) and the fourth next (8)
    // are left out.
    expect(find.text('Now showing (1)'), findsOneWidget);
    expect(find.text('Up next (3)'), findsOneWidget);
    expect(find.text('Just finished (3)'), findsOneWidget);
    for (final id in [8, 9, 10]) {
      expect(find.byKey(ValueKey('boardShowtime-$id')), findsNothing);
    }

    Finder card(int id, String text) => find.descendant(
      of: find.byKey(ValueKey('boardShowtime-$id')),
      matching: find.text(text),
    );
    // Playing: people inside now, tickets of the room.
    expect(card(1, 'Now showing'), findsOneWidget);
    expect(card(1, '25'), findsOneWidget);
    expect(card(1, 'watching now'), findsOneWidget);
    expect(card(1, '30/120'), findsOneWidget);
    expect(card(1, inception.title), findsOneWidget);
    // Next: booked and held seats.
    expect(card(5, 'Starts in 20 min'), findsOneWidget);
    expect(card(5, 'awaiting payment'), findsOneWidget);
    expect(card(5, '3/120'), findsOneWidget);
    // Finished: tickets sold and how many came.
    expect(card(2, 'Ended 10 min ago'), findsOneWidget);
    expect(card(2, '10'), findsOneWidget);
    expect(card(2, 'came in'), findsOneWidget);

    // The showtime opens with where each customer sits.
    await tester.tap(find.byKey(const ValueKey('boardShowtime-1')));
    await pumpRoute(tester);
    expect(find.text('Customers (2)'), findsOneWidget);
    expect(find.text('a@test.local'), findsOneWidget);
    expect(
      find.text('A1, A2 • BK-A • Checked in ${formatTime(checkedInAt)}'),
      findsOneWidget,
    );
    expect(find.text('B1 • BK-B • Awaiting payment'), findsOneWidget);
  });
}

// Showtimes around now: 1 is playing, 2, 3, 4 and 10 finished, 5 to 8 come next
// and 9 (playing) was cancelled. Times keep 30 seconds of slack so minute
// counts do not change while the test runs.
StaffService _api(DateTime checkedInAt) {
  final now = DateTime.now();
  DateTime at(int minutes) =>
      now.add(Duration(minutes: minutes, seconds: minutes < 0 ? -30 : 30));
  Map<String, Object?> show(int id, int start, int end, [String? status]) => {
    'id': id,
    'movieId': inception.id,
    'roomId': 1,
    'startTime': at(start).toIso8601String(),
    'endTime': at(end).toIso8601String(),
    'price': 90000,
    'status': status ?? 'OPEN',
  };
  final window = [
    show(10, -440, -320),
    show(4, -320, -200),
    show(3, -180, -60),
    show(2, -130, -10),
    show(1, -30, 90),
    show(9, -20, 100, 'CANCELLED'),
    show(5, 20, 140),
    show(6, 60, 180),
    show(7, 90, 210),
    show(8, 120, 240),
  ];
  final stats = [
    {'showtimeId': 1, 'bookings': 12, 'soldSeats': 30, 'checkedInSeats': 25},
    {
      'showtimeId': 2,
      'bookings': 5,
      'soldSeats': 10,
      'heldSeats': 2,
      'checkedInSeats': 8,
    },
    {'showtimeId': 5, 'bookings': 1, 'heldSeats': 3},
  ];
  Map<String, Object?> page(List<Object?> items, [int? total]) => {
    'items': items,
    'pageNumber': 1,
    'pageSize': 50,
    'totalCount': total ?? items.length,
    'totalPages': 1,
  };
  Map<String, Object?> seat(
    int id,
    String label,
    int booking,
    String code,
    String email,
    String status, [
    DateTime? checkedIn,
  ]) => {
    'seatId': id,
    'seatLabel': label,
    'bookingId': booking,
    'bookingCode': code,
    'userId': 100 + booking,
    'customerEmail': email,
    'status': status,
    'checkedInAt': checkedIn?.toIso8601String(),
  };

  return StaffService(
    client: ApiClient(
      httpClient: MockClient((request) async {
        final url = request.url;
        final Object body = switch (url.path) {
          '/api/v1/bookings/date-range' => page(const [], 7),
          '/api/showtimes/date-range'
              when url.queryParameters['pageSize'] == '1' =>
            page(const [], 20),
          '/api/showtimes/date-range' => page(window),
          '/api/v1/bookings/showtimes/stats' => [
            for (final row in stats)
              if (url.queryParametersAll['showtimeIds']?.contains(
                    '${row['showtimeId']}',
                  ) ??
                  true)
                row,
          ],
          '/api/v1/movies' => page([
            {
              'id': inception.id,
              'title': inception.title,
              'durationMinutes': inception.durationMinutes,
              'status': 'ACTIVE',
            },
          ]),
          '/api/rooms' => page([
            {'id': 1, 'name': 'IMAX 1', 'totalSeats': 120},
          ]),
          '/api/showtimes/1' => show(1, -30, 90),
          '/api/seats/room/1' => [
            for (final (index, label) in ['A1', 'A2', 'B1'].indexed)
              {
                'id': index + 1,
                'roomId': 1,
                'seatRow': label[0],
                'seatNumber': int.parse(label.substring(1)),
                'seatType': 'NORMAL',
              },
          ],
          '/api/v1/bookings/showtime/1/seats' => [
            seat(2, 'A2', 50, 'BK-A', 'a@test.local', 'CONFIRMED', checkedInAt),
            seat(1, 'A1', 50, 'BK-A', 'a@test.local', 'CONFIRMED', checkedInAt),
            seat(3, 'B1', 51, 'BK-B', 'b@test.local', 'PENDING'),
          ],
          _ => page(const []),
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    ),
  );
}
