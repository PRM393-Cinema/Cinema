import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/showtime.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

Map<String, Object?> _imaxJson(DateTime start) => {
  'id': 7,
  'movieId': inception.id,
  'roomId': 1,
  'startTime': start.toIso8601String(),
  'endTime': start.add(const Duration(hours: 3)).toIso8601String(),
  'price': 90000,
  'format': 'IMAX',
  'formatSurcharge': 40000,
  'seatPrices': {'NORMAL': 130000, 'VIP': 156000, 'SWEETBOX': 169000},
  'status': 'OPEN',
};

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('A 3D or IMAX showtime names its format next to the room', () {
    final imax = Showtime.fromJson(_imaxJson(tomorrowEvening()));
    expect(imax.format, 'IMAX');
    expect(imax.roomLabel, 'Room 1 · IMAX');
    expect(imax.priceOf('NORMAL'), 130000);
    expect(showtimeFixture().roomLabel, 'Room 1');
  });

  testWidgets('Customers see the format and the price with its surcharge', (
    tester,
  ) async {
    final catalog = FakeCatalogRepository(
      showtimes: [Showtime.fromJson(_imaxJson(tomorrowEvening()))],
    );
    await tester.pumpWidget(
      buildTestApp(
        catalogRepository: catalog,
        initialRoute: AppRoutes.movieDetail(inception.id),
      ),
    );
    await pumpRoute(tester);
    await tester.scrollUntilVisible(
      find.text('Room 1 · IMAX'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Room 1 · IMAX'), findsOneWidget);
    expect(find.text(formatVnd(130000)), findsOneWidget);
  });

  testWidgets('Staff change the format of a showtime', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final start = tomorrowEvening();
    final saved = <Map<String, Object?>>[];
    final service = StaffService(
      client: ApiClient(
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'PUT') {
            final body = (jsonDecode(request.body) as Map)
                .cast<String, Object?>();
            saved.add(body);
            return _json({..._imaxJson(start), 'format': body['format']});
          }
          if (path == '/api/v1/movies') {
            return _json(
              _page([
                {
                  'id': inception.id,
                  'title': inception.title,
                  'durationMinutes': inception.durationMinutes,
                  'genre': inception.genre,
                  'status': 'ACTIVE',
                },
              ]),
            );
          }
          if (path == '/api/rooms') {
            return _json(
              _page([
                {'id': 1, 'name': 'Phòng Chiếu 01 (IMAX)', 'totalSeats': 54},
              ]),
            );
          }
          return _json(_imaxJson(start));
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
        initialRoute: AppRoutes.staffEditShowtime(7),
      ),
    );
    await pumpRoute(tester);

    expect(find.text('IMAX'), findsOneWidget);
    await tester.tap(find.byKey(const Key('showtimeFormat')));
    await pumpRoute(tester);
    await tester.tap(find.text('3D').last);
    await pumpRoute(tester);
    await tester.ensureVisible(find.text('Save showtime'));
    await tester.tap(find.text('Save showtime'));
    await pumpFrames(tester);

    expect(saved.single['format'], '3D');
    expect(saved.single['price'], 90000);
  });
}

Map<String, Object?> _page(List<Object?> items) => {
  'items': items,
  'pageNumber': 1,
  'pageSize': 50,
  'totalPages': 1,
  'totalCount': items.length,
};

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
