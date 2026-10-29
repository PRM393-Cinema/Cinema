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

final _admin = AuthUser.fromJson({
  ...customerUser.toJson(),
  'userId': 1,
  'roles': ['ROLE_ADMIN'],
});
final _staff = AuthUser.fromJson({
  ...customerUser.toJson(),
  'userId': 2,
  'roles': ['ROLE_STAFF'],
});

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('Admin website access', () {
    testWidgets('Signed out: a page link asks to sign in, with no sign up', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildAdminTestApp(initialRoute: AppRoutes.adminMovies),
      );
      await pumpRoute(tester);

      expect(find.byKey(const Key('loginTitle')), findsOneWidget);
      expect(find.text('Create an account'), findsNothing);
    });

    testWidgets('A customer account is pointed to the cinema website', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildAdminTestApp(
          authenticated: true,
          initialRoute: AppRoutes.staffDashboard,
        ),
      );
      await pumpRoute(tester);

      expect(find.byKey(const Key('staffOnlyTitle')), findsOneWidget);
      expect(find.text('Staff dashboard'), findsNothing);
    });

    testWidgets('Staff see staff pages only; admin pages open the dashboard', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildAdminTestApp(
          authenticated: true,
          user: _staff,
          initialRoute: AppRoutes.adminMovies,
        ),
      );
      await pumpRoute(tester);

      expect(find.text('Staff dashboard'), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      for (final label in ['Dashboard', 'Operations', 'Profile']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final label in ['Movies', 'Rooms', 'Accounts']) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('Admins move between sections from the navigation', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildAdminTestApp(authenticated: true, user: _admin),
      );
      await pumpRoute(tester);
      expect(find.text('ADMIN'), findsOneWidget);

      await tester.tap(find.text('Movies'));
      await pumpRoute(tester);
      expect(find.byKey(const Key('addMovieButton')), findsOneWidget);

      await tester.tap(find.text('Rooms').first);
      await pumpRoute(tester);
      expect(find.byKey(const Key('addRoomButton')), findsOneWidget);
      // Sections replace each other, so there is nothing to go back to.
      expect(find.byTooltip('Back'), findsNothing);
    });

    testWidgets('The admin dashboard shows this month’s bookings and sales', (
      tester,
    ) async {
      final api = _FakeApi()
        ..movies.add(_movie(1, 'Old Movie'))
        ..bookingsThisMonth = 12
        ..revenue = 1530000;
      await _openAdmin(tester, api, AppRoutes.adminDashboard);

      expect(find.byKey(const Key('businessStats')), findsOneWidget);
      for (final (label, value) in [
        ('Bookings this month', '12'),
        ('Revenue this month', formatVnd(1530000)),
        ('Movies showing', '1'),
        ('Showtimes today', '0'),
      ]) {
        final tile = find.ancestor(
          of: find.text(label),
          matching: find.byType(Column),
        );
        expect(
          find.descendant(of: tile.first, matching: find.text(value)),
          findsOneWidget,
          reason: label,
        );
      }
      final summary = api.reads.firstWhere(
        (uri) => uri.path == '/api/v1/payments/summary',
      );
      final start = DateTime.parse(summary.queryParameters['start']!);
      expect((start.day, start.hour), (1, 0));
    });

    testWidgets('Narrow windows open the navigation from the menu', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        buildAdminTestApp(
          authenticated: true,
          user: _admin,
          initialRoute: AppRoutes.adminRooms,
        ),
      );
      await pumpRoute(tester);
      expect(find.byType(NavigationRail), findsNothing);

      await tester.tap(find.byTooltip('Menu'));
      await pumpRoute(tester);
      await tester.tap(find.text('Movies'));
      await pumpRoute(tester);

      expect(find.byKey(const Key('addMovieButton')), findsOneWidget);
    });

    testWidgets('The customer app points staff accounts to the admin site', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(authenticated: true, user: _staff));
      await pumpRoute(tester);

      expect(find.byKey(const Key('managementAccountTitle')), findsOneWidget);
    });

    testWidgets('The customer app has no staff pages', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          user: _admin,
          initialRoute: AppRoutes.adminUsers,
        ),
      );
      await pumpRoute(tester);

      expect(find.byKey(const Key('managementAccountTitle')), findsOneWidget);
      expect(find.text('Manage accounts'), findsNothing);
    });
  });

  group('Movies', () {
    testWidgets('Adding a movie sends the form and shows it in the list', (
      tester,
    ) async {
      final api = _FakeApi()..movies.add(_movie(1, 'Old Movie'));
      await _openAdmin(tester, api, AppRoutes.adminMovies);
      expect(find.text('Old Movie'), findsOneWidget);
      expect(find.text('Showing'), findsWidgets);
      expect(find.text('1 movie'), findsOneWidget);

      await tester.tap(find.byKey(const Key('addMovieButton')));
      await pumpRoute(tester);
      await tester.tap(find.byKey(const Key('saveMovieButton')));
      await pumpRoute(tester);
      expect(find.text('Required.'), findsOneWidget);
      expect(find.text('Enter 1 to 600 minutes.'), findsOneWidget);

      await _type(tester, 'movieTitleField', '  New Movie ');
      await _type(tester, 'movieDurationField', '125');
      await _type(tester, 'movieGenreField', 'Drama');
      await _type(tester, 'moviePosterField', 'poster.jpg');
      await tester.ensureVisible(find.byKey(const Key('saveMovieButton')));
      await tester.tap(find.byKey(const Key('saveMovieButton')));
      await pumpRoute(tester);
      expect(
        find.text('Enter a link starting with http:// or https://.'),
        findsOneWidget,
      );
      expect(api.writes, isEmpty);

      await _type(tester, 'moviePosterField', 'https://img.test/new.jpg');
      await tester.ensureVisible(find.byKey(const Key('saveMovieButton')));
      await tester.tap(find.byKey(const Key('saveMovieButton')));
      await pumpRoute(tester);

      final (method, path, body) = api.writes.single;
      expect('$method $path', 'POST /api/v1/movies');
      expect(body['title'], 'New Movie');
      expect(body['durationMinutes'], 125);
      expect(body['genre'], 'Drama');
      expect(body['posterUrl'], 'https://img.test/new.jpg');
      expect(body.containsKey('status'), isFalse);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Added New Movie.'), findsOneWidget);
      expect(find.text('New Movie'), findsOneWidget);
    });

    testWidgets('A refused save keeps the form open with the reason', (
      tester,
    ) async {
      final api = _FakeApi()
        ..movies.add(_movie(1, 'Old Movie'))
        ..refuse = "Movie with title 'Old Movie' already exists.";
      await _openAdmin(tester, api, AppRoutes.adminMovies);

      await tester.tap(find.byKey(const Key('editMovie-1')));
      await pumpRoute(tester);
      expect(find.text('Edit movie'), findsOneWidget);
      expect(find.text('Sep 1, 2026'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('saveMovieButton')));
      await tester.tap(find.byKey(const Key('saveMovieButton')));
      await pumpRoute(tester);

      expect(api.writes.single.$1, 'PUT');
      expect(api.writes.single.$2, '/api/v1/movies/1');
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.text("Movie with title 'Old Movie' already exists."),
        findsOneWidget,
      );
    });

    testWidgets('Stopping a movie and showing it again', (tester) async {
      final api = _FakeApi()..movies.add(_movie(4, 'Night Train'));
      await _openAdmin(tester, api, AppRoutes.adminMovies);

      await tester.tap(find.byKey(const Key('toggleMovie-4')));
      await pumpRoute(tester);
      await tester.tap(find.text('Confirm'));
      await pumpRoute(tester);
      expect(api.writes.last.$1, 'DELETE');
      expect(api.writes.last.$2, '/api/v1/movies/4');
      expect(find.text('Stopped'), findsOneWidget);
      expect(find.text('Night Train is no longer showing.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('toggleMovie-4')));
      await pumpRoute(tester);
      await tester.tap(find.text('Confirm'));
      await pumpRoute(tester);
      final (method, path, body) = api.writes.last;
      expect('$method $path', 'PUT /api/v1/movies/4');
      expect(body['status'], 'ACTIVE');
      expect(body['title'], 'Night Train');
      expect(find.text('Stopped'), findsNothing);
    });

    testWidgets('The movie form fits a phone-width window', (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        buildAdminTestApp(
          authenticated: true,
          user: _admin,
          staffService: _FakeApi().service,
          initialRoute: AppRoutes.adminMovies,
        ),
      );
      await pumpRoute(tester);

      await tester.tap(find.byKey(const Key('addMovieButton')));
      await pumpRoute(tester);

      // Fields are stacked, so the release date is shown in full.
      final duration = find.byKey(const Key('movieDurationField'));
      final release = find.byKey(const Key('movieReleaseDateField'));
      expect(
        find.descendant(
          of: release,
          matching: find.text(formatDate(DateUtils.dateOnly(DateTime.now()))),
        ),
        findsOneWidget,
      );
      expect(tester.getTopLeft(release).dx, tester.getTopLeft(duration).dx);
      expect(
        tester.getTopLeft(release).dy,
        greaterThan(tester.getBottomLeft(duration).dy),
      );
    });

    testWidgets('The status filter and the search ask the right list', (
      tester,
    ) async {
      final api = _FakeApi()..movies.add(_movie(1, 'Old Movie'));
      await _openAdmin(tester, api, AppRoutes.adminMovies);

      await tester.tap(find.byKey(const Key('movieStatusFilter')));
      await pumpRoute(tester);
      await tester.tap(find.text('Stopped').last);
      await pumpRoute(tester);
      expect(api.reads.last.path, '/api/v1/movies/status/INACTIVE');
      expect(find.text('No matching movies.'), findsOneWidget);

      await _type(tester, 'movieSearchField', 'old');
      await tester.tap(find.byTooltip('Search movies'));
      await pumpRoute(tester);
      expect(api.reads.last.path, '/api/v1/movies/search');
      expect(api.reads.last.queryParameters['keyword'], 'old');
      expect(find.text('All movies'), findsOneWidget);
    });
  });

  group('Rooms', () {
    testWidgets('Adding a room creates it and generates its seats', (
      tester,
    ) async {
      final api = _FakeApi();
      await _openAdmin(tester, api, AppRoutes.adminRooms);
      expect(find.text('0 rooms'), findsOneWidget);

      await tester.tap(find.byKey(const Key('addRoomButton')));
      await pumpRoute(tester);
      expect(find.textContaining('80 standard seats'), findsOneWidget);
      await _type(tester, 'roomNameField', 'Room 13');
      await _type(tester, 'roomRowsField', '27');
      await tester.tap(find.byKey(const Key('saveRoomButton')));
      await pumpRoute(tester);
      expect(find.text('Enter 1 to 26.'), findsOneWidget);
      expect(api.writes, isEmpty);

      await _type(tester, 'roomRowsField', '5');
      await _type(tester, 'roomSeatsPerRowField', '12');
      expect(find.textContaining('60 standard seats'), findsOneWidget);
      await tester.tap(find.byKey(const Key('saveRoomButton')));
      await pumpRoute(tester);

      expect(api.writes.map((write) => '${write.$1} ${write.$2}'), [
        'POST /api/rooms',
        'POST /api/seats/generate',
      ]);
      expect(api.writes.first.$3, {
        'name': 'Room 13',
        'totalSeats': 60,
        'rows': 5,
        'seatsPerRow': 12,
      });
      expect(api.writes.last.$3['roomId'], 100);
      expect(api.writes.last.$3['rows'], 5);
      expect(api.writes.last.$3['seatsPerRow'], 12);
      expect(find.text('Added Room 13 with 60 seats.'), findsOneWidget);
      expect(find.text('Room 13'), findsOneWidget);
    });

    testWidgets('Seats that fail to generate remove the new room again', (
      tester,
    ) async {
      final api = _FakeApi()..failSeats = true;
      await _openAdmin(tester, api, AppRoutes.adminRooms);

      await tester.tap(find.byKey(const Key('addRoomButton')));
      await pumpRoute(tester);
      await _type(tester, 'roomNameField', 'Room 13');
      await tester.tap(find.byKey(const Key('saveRoomButton')));
      await pumpRoute(tester);

      expect(api.writes.map((write) => '${write.$1} ${write.$2}'), [
        'POST /api/rooms',
        'POST /api/seats/generate',
        'DELETE /api/rooms/100',
      ]);
      expect(api.rooms, isEmpty);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Seats could not be generated.'), findsOneWidget);
    });

    testWidgets('Renaming a room and a refused delete', (tester) async {
      final api = _FakeApi()
        ..rooms.add({'id': 3, 'name': 'Room 03', 'totalSeats': 80})
        ..refuse = 'Cannot delete room because it has existing showtimes.';
      await _openAdmin(tester, api, AppRoutes.adminRooms);
      expect(find.text('80 seats'), findsOneWidget);

      await tester.tap(find.byKey(const Key('deleteRoom-3')));
      await pumpRoute(tester);
      await tester.tap(find.text('Confirm'));
      await pumpRoute(tester);
      expect(api.writes.single.$2, '/api/rooms/3');
      expect(
        find.text('Cannot delete room because it has existing showtimes.'),
        findsOneWidget,
      );
      expect(find.text('Room 03'), findsOneWidget);

      api.refuse = null;
      await tester.tap(find.byKey(const Key('renameRoom-3')));
      await pumpRoute(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(EditableText),
        ),
        'IMAX 1',
      );
      await tester.tap(find.text('Continue'));
      await pumpRoute(tester);

      final (method, path, body) = api.writes.last;
      expect('$method $path', 'PUT /api/rooms/3');
      expect(body['name'], 'IMAX 1');
      expect(body['totalSeats'], 80);
      expect(find.text('Renamed Room 03 to IMAX 1.'), findsOneWidget);
      expect(find.text('IMAX 1'), findsOneWidget);
    });

    testWidgets('Seats are painted many at a time', (tester) async {
      tester.view.physicalSize = const Size(1440, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _FakeApi()
        ..rooms.add({'id': 3, 'name': 'Room 03', 'totalSeats': 8})
        ..seats[3] = [
          for (final (i, label) in [
            'A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3', 'B4', //
          ].indexed)
            _seat(i + 1, 3, label[0], int.parse(label.substring(1))),
        ];
      await _openAdmin(tester, api, AppRoutes.staffRecord('rooms', 3));
      Offset seat(String label) =>
          tester.getCenter(find.byKey(ValueKey('roomSeat-$label')));

      // Dragging across row A makes its seats VIP in one request.
      await tester.tap(find.byKey(const Key('paint-VIP')));
      await pumpRoute(tester);
      await tester.timedDragFrom(
        seat('A1'),
        seat('A3') - seat('A1'),
        const Duration(milliseconds: 400),
      );
      await pumpRoute(tester);
      var (method, path, body) = api.writes.last;
      expect('$method $path', 'PUT /api/seats/room/3/types');
      expect(body, {
        'seatIds': [1, 2, 3],
        'seatType': 'VIP',
      });
      expect(find.text('3 seats are now VIP.'), findsOneWidget);
      expect(find.text('VIP (3)'), findsOneWidget);

      // Tapping a row letter paints the whole row.
      await tester.tap(find.byKey(const ValueKey('rowLabel-B')).first);
      await pumpRoute(tester);
      (method, path, body) = api.writes.last;
      expect(body['seatIds'], [5, 6, 7, 8]);
      expect(find.text('VIP (7)'), findsOneWidget);

      // A sweetbox brings its pair; seats that already have the type are
      // left out of the request.
      await tester.tap(find.byKey(const Key('paint-SWEETBOX')));
      await pumpRoute(tester);
      await tester.tapAt(seat('A1'));
      await pumpRoute(tester);
      expect(api.writes.last.$3, {
        'seatIds': [1],
        'seatType': 'SWEETBOX',
      });
      expect(find.text('2 seats are now Sweetbox.'), findsOneWidget);
      expect(find.text('Sweetbox (2)'), findsOneWidget);

      // Back to one seat at a time: a tap opens the seat's menu.
      await tester.tap(find.byKey(const Key('paintOff')));
      await pumpRoute(tester);
      await tester.tap(find.byKey(const ValueKey('roomSeat-B4')));
      await pumpRoute(tester);
      expect(find.byType(CheckedPopupMenuItem<String>), findsNWidgets(3));
    });

    testWidgets('The seat map grows row by row and follows other changes', (
      tester,
    ) async {
      final api = _FakeApi()
        ..rooms.add({'id': 3, 'name': 'Room 03', 'totalSeats': 6})
        ..seats[3] = [
          for (final (i, label) in ['A1', 'A2', 'A3', 'B1', 'B2', 'B3'].indexed)
            _seat(i + 1, 3, label[0], int.parse(label.substring(1))),
        ];
      await _openAdmin(tester, api, AppRoutes.staffRecord('rooms', 3));

      String summary() =>
          tester.widget<Text>(find.byKey(const Key('roomSeatSummary'))).data!;
      expect(summary(), '2 rows • 6 seats');
      expect(find.byKey(const ValueKey('roomSeat-B3')), findsOneWidget);

      // Adding 4 seats fills new rows of 3 seats.
      await tester.tap(find.text('Change seat count'));
      await pumpRoute(tester);
      await _type(tester, 'seatCountField', '10');
      expect(find.text('6 to 10 seats (+4): adds C1–C3, D1.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('saveSeatCountButton')));
      await pumpRoute(tester);

      final (method, path, body) = api.writes.last;
      expect('$method $path', 'PUT /api/seats/room/3/capacity');
      expect(body, {'totalSeats': 10, 'seatsPerRow': 3});
      expect(summary(), '4 rows • 10 seats');
      expect(find.byKey(const ValueKey('roomSeat-D1')), findsOneWidget);
      expect(find.text('Just added'), findsOneWidget);
      expect(find.text('Room 03 now has 10 seats (+4).'), findsOneWidget);

      // A seat's type is changed from the map.
      await tester.tap(find.byKey(const ValueKey('roomSeat-A1')));
      await pumpRoute(tester);
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'VIP'),
      );
      await pumpRoute(tester);
      expect(api.writes.last.$2, '/api/seats/1/type');
      expect(api.writes.last.$3['seatType'], 'VIP');
      expect(find.text('VIP (1)'), findsOneWidget);

      // Seats added elsewhere show up on the next refresh.
      api.seats[3]!.add(_seat(11, 3, 'D', 2));
      await tester.pump(const Duration(seconds: 5));
      await pumpRoute(tester);
      expect(summary(), '4 rows • 11 seats');
      expect(find.byKey(const ValueKey('roomSeat-D2')), findsOneWidget);

      // A sweetbox takes its pair along (1 with 2); a seat without a pair
      // cannot become one.
      await tester.tap(find.byKey(const ValueKey('roomSeat-C3')));
      await pumpRoute(tester);
      final lonely = find.widgetWithText(
        CheckedPopupMenuItem<String>,
        'Sweetbox (no C4 to pair with)',
      );
      expect(
        tester.widget<CheckedPopupMenuItem<String>>(lonely).enabled,
        false,
      );
      await tester.tapAt(Offset.zero);
      await pumpRoute(tester);

      await tester.tap(find.byKey(const ValueKey('roomSeat-B1')));
      await pumpRoute(tester);
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'Sweetbox (with B2)'),
      );
      await pumpRoute(tester);
      expect(find.text('B1 and B2 are now Sweetbox.'), findsOneWidget);
      expect(find.text('Sweetbox (2)'), findsOneWidget);

      // Removing B2 would leave B1 without its pair.
      await tester.tap(find.text('Change seat count'));
      await pumpRoute(tester);
      await _type(tester, 'seatCountField', '4');
      expect(
        find.text(
          '11 to 4 seats (-7): removes B2–B3, C1–C3, D1–D2. B1 becomes a '
          'standard seat: its sweetbox pair is removed.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await pumpRoute(tester);
    });
  });
}

Future<void> _openAdmin(WidgetTester tester, _FakeApi api, String route) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    buildAdminTestApp(
      authenticated: true,
      user: _admin,
      staffService: api.service,
      initialRoute: route,
    ),
  );
  await pumpRoute(tester);
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.enterText(
    find.descendant(of: field, matching: find.byType(EditableText)),
    text,
  );
  await tester.pump();
}

Map<String, Object?> _movie(int id, String title) => {
  'id': id,
  'title': title,
  'description': '',
  'durationMinutes': 110,
  'genre': 'Action',
  'language': 'English',
  'releaseDate': '2026-09-01',
  'posterUrl': '',
  'trailerUrl': '',
  'status': 'ACTIVE',
};

Map<String, Object?> _seat(int id, int roomId, String row, int number) => {
  'id': id,
  'roomId': roomId,
  'seatRow': row,
  'seatNumber': number,
  'seatType': 'NORMAL',
};

// Movie and room endpoints of the API, kept in memory. A refuse message
// fails the next writes with 400.
class _FakeApi {
  final movies = <Map<String, Object?>>[];
  final rooms = <Map<String, Object?>>[];
  // Seat maps by room id.
  final seats = <int, List<Map<String, Object?>>>{};
  final reads = <Uri>[];
  final writes = <(String, String, Map<String, Object?>)>[];
  String? refuse;
  bool failSeats = false;
  // Dashboard figures.
  int bookingsThisMonth = 0;
  double revenue = 0;

  late final service = StaffService(
    client: ApiClient(httpClient: MockClient(_handle)),
  );

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'GET') {
      reads.add(request.url);
      final id = int.tryParse(request.url.pathSegments.last);
      if (path.startsWith('/api/seats/room/')) return _json(seats[id] ?? []);
      if (path == '/api/v1/payments/summary') {
        return _json({'paidCount': 1, 'revenue': revenue, 'refundedAmount': 0});
      }
      if (path.startsWith('/api/v1/bookings')) {
        return _json({
          'items': const [],
          'pageNumber': 1,
          'pageSize': 10,
          'totalCount': bookingsThisMonth,
          'totalPages': 0,
        });
      }
      if (path.startsWith('/api/showtimes')) return _page(const []);
      if (path.startsWith('/api/rooms/') && id != null) {
        return _json(rooms.firstWhere((room) => room['id'] == id));
      }
      if (path.startsWith('/api/rooms')) return _page(rooms);
      if (path == '/api/v1/movies/status/INACTIVE') {
        return _page([
          for (final movie in movies)
            if (movie['status'] == 'INACTIVE') movie,
        ]);
      }
      return _page(movies);
    }

    final body = request.body.isEmpty
        ? <String, Object?>{}
        : (jsonDecode(request.body) as Map).cast<String, Object?>();
    writes.add((request.method, path, body));
    if (refuse != null) return _problem(refuse!);

    final segments = request.url.pathSegments;
    final id = int.tryParse(segments.last);
    switch ((request.method, path)) {
      case ('POST', '/api/v1/movies'):
        final movie = {..._movie(50, ''), ...body, 'status': 'ACTIVE'};
        movies.insert(0, movie);
        return _json(movie);
      case ('POST', '/api/rooms'):
        final room = {
          'id': 100,
          'name': body['name'],
          'totalSeats': body['totalSeats'],
        };
        rooms.add(room);
        return _json(room);
      case ('POST', '/api/seats/generate'):
        return failSeats
            ? _problem('Seats could not be generated.')
            : _page(const []);
    }
    if (path.endsWith('/types')) {
      // Like the API, painting a sweetbox brings its pair.
      final map = seats[int.parse(segments[3])]!;
      final type = body['seatType'] as String;
      final ids = (body['seatIds'] as List).cast<int>().toSet();
      for (final seat in map.where((s) => ids.contains(s['id']))) {
        seat['seatType'] = type;
        final number = seat['seatNumber'] as int;
        final pair = map
            .where(
              (s) =>
                  s['seatRow'] == seat['seatRow'] &&
                  s['seatNumber'] == (number.isOdd ? number + 1 : number - 1),
            )
            .firstOrNull;
        if (pair != null && type == 'SWEETBOX') pair['seatType'] = type;
      }
      return _json(map);
    }
    if (path.endsWith('/capacity')) {
      final roomId = int.parse(segments[3]);
      final map = seats[roomId]!;
      final perRow = body['seatsPerRow'] as int;
      while (map.length < (body['totalSeats'] as int)) {
        final last = map.last;
        final full = map.where((s) => s['seatRow'] == last['seatRow']).length;
        final next = full >= perRow;
        map.add(
          _seat(
            map.length + 1,
            roomId,
            next
                ? String.fromCharCode(
                    (last['seatRow'] as String).codeUnitAt(0) + 1,
                  )
                : last['seatRow'] as String,
            next ? 1 : (last['seatNumber'] as int) + 1,
          ),
        );
      }
      map.length = body['totalSeats'] as int;
      return _json(map);
    }
    if (path.startsWith('/api/seats/')) {
      // Like the API, a sweetbox changes type together with its pair.
      final map = seats.values.firstWhere(
        (map) => map.any((seat) => seat['id'] == int.parse(segments[2])),
      );
      final seat = map.firstWhere((s) => s['id'] == int.parse(segments[2]));
      final number = seat['seatNumber'] as int;
      final pair = map
          .where(
            (s) =>
                s['seatRow'] == seat['seatRow'] &&
                s['seatNumber'] == (number.isOdd ? number + 1 : number - 1),
          )
          .firstOrNull;
      if (pair != null &&
          (body['seatType'] == 'SWEETBOX' ||
              (seat['seatType'] == 'SWEETBOX' &&
                  pair['seatType'] == 'SWEETBOX'))) {
        pair['seatType'] = body['seatType'];
      }
      seat['seatType'] = body['seatType'];
      return _json(seat);
    }
    if (path.startsWith('/api/v1/movies/')) {
      final movie = movies.firstWhere((movie) => movie['id'] == id);
      if (request.method == 'DELETE') {
        movie['status'] = 'INACTIVE';
        return http.Response('', 204);
      }
      movie.addAll(body);
      return _json(movie);
    }
    if (path.startsWith('/api/rooms/')) {
      if (request.method == 'DELETE') {
        rooms.removeWhere((room) => room['id'] == id);
        return http.Response('', 204);
      }
      final room = rooms.firstWhere((room) => room['id'] == id);
      room['name'] = body['name'];
      return _json(room);
    }
    return http.Response('', 404);
  }

  http.Response _page(List<Map<String, Object?>> items) => _json({
    'items': items,
    'pageNumber': 1,
    'pageSize': 10,
    'totalCount': items.length,
    'totalPages': items.isEmpty ? 0 : 1,
  });

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  http.Response _problem(String detail) =>
      _json({'title': 'Bad Request', 'status': 400, 'detail': detail}, 400);
}
