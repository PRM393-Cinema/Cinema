import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:cinema_fe/features/staff/screens/staff_check_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';

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

  group('Staff check-in', () {
    testWidgets('A paid ticket is found by its code and checked in once', (
      tester,
    ) async {
      final api = _BookingApi();
      await tester.pumpWidget(
        buildAdminTestApp(
          authenticated: true,
          user: _staff,
          staffService: api.service,
          initialRoute: AppRoutes.staffCheckIn,
        ),
      );
      await pumpRoute(tester);
      expect(find.text('Ticket check-in'), findsWidgets);

      // A handheld scanner types the code and presses Enter.
      await tester.enterText(find.byKey(const Key('checkInCode')), 'bk-paid');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await pumpRoute(tester);
      expect(find.text(inception.title), findsOneWidget);
      expect(find.text('Room 1'), findsOneWidget);
      expect(find.text('A1, A2 (2)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('checkInButton')));
      await pumpRoute(tester);
      expect(api.checkIns, ['BK-PAID']);
      expect(
        find.text('Checked in. Let the customer in to Room 1: seats A1, A2.'),
        findsOneWidget,
      );
      expect(find.text('Checked in'), findsOneWidget);

      // The same ticket again: it was used.
      await tester.enterText(find.byKey(const Key('checkInCode')), 'BK-PAID');
      await tester.tap(find.text('Find ticket'));
      await pumpRoute(tester);
      expect(find.textContaining('already checked in'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byKey(const Key('checkInButton')), findsNothing);
      expect(find.byKey(const Key('checkInTicket')), findsNothing);
      expect(find.text(inception.title), findsNothing);
      expect(find.text('khach@test.local'), findsNothing);
    });

    testWidgets('Unknown and unpaid tickets cannot be checked in', (
      tester,
    ) async {
      final api = _BookingApi();
      await tester.pumpWidget(
        buildAdminTestApp(
          authenticated: true,
          user: _staff,
          staffService: api.service,
          initialRoute: AppRoutes.staffCheckIn,
        ),
      );
      await pumpRoute(tester);

      await tester.enterText(find.byKey(const Key('checkInCode')), 'BK-NOPE');
      await tester.tap(find.text('Find ticket'));
      await pumpRoute(tester);
      expect(find.text('No booking has the code BK-NOPE.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('checkInCode')), 'BK-UNPAID');
      await tester.tap(find.text('Find ticket'));
      await pumpRoute(tester);
      expect(find.text('This ticket has not been paid yet.'), findsOneWidget);
      expect(find.byKey(const Key('checkInButton')), findsNothing);
      expect(api.checkIns, isEmpty);
    });

    testWidgets('Scanning the QR code finds the ticket', (tester) async {
      final api = _BookingApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckInPanel(
              service: api.service,
              canScan: true,
              scanner: (_) async => 'BK-PAID',
            ),
          ),
        ),
      );

      await tester.tap(find.text('Scan QR'));
      await pumpRoute(tester);
      expect(find.byKey(const Key('checkInButton')), findsOneWidget);
      expect(find.text('BK-PAID'), findsWidgets);
    });

    for (final legacy in [false, true]) {
      testWidgets('Used ticket popup hides details (legacy API: $legacy)', (
        tester,
      ) async {
        final api = _BookingApi(legacyUsedLookup: legacy);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CheckInPanel(
                service: api.service,
                canScan: true,
                scanner: (_) async => 'BK-USED',
              ),
            ),
          ),
        );
        await tester.tap(find.text('Scan QR'));
        await pumpRoute(tester);
        expect(find.textContaining('already checked in'), findsOneWidget);
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byKey(const Key('checkInTicket')), findsNothing);
        expect(find.byKey(const Key('checkInButton')), findsNothing);
        expect(find.text(inception.title), findsNothing);
        expect(find.text('khach@test.local'), findsNothing);
        expect(api.requests, ['/api/v1/bookings/code/BK-USED']);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('checkInCode')))
              .controller!
              .text,
          isEmpty,
        );

        // The modal requires acknowledgement before another ticket is scanned.
        await tester.tapAt(const Offset(5, 5));
        await pumpRoute(tester);
        expect(find.byType(Dialog), findsOneWidget);
        await tester.tap(find.text('Back to scanner'));
        await pumpRoute(tester);
        expect(find.byType(Dialog), findsNothing);
        expect(find.textContaining('already checked in'), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('checkInCode')))
              .focusNode!
              .hasFocus,
          isTrue,
        );
        await tester.enterText(find.byKey(const Key('checkInCode')), 'BK-PAID');
        await tester.tap(find.text('Find ticket'));
        await pumpRoute(tester);
        expect(find.byKey(const Key('checkInButton')), findsOneWidget);
      });
    }

    testWidgets(
      'A concurrent check-in rejection removes previously shown details',
      (tester) async {
        final api = _BookingApi();
        await tester.pumpWidget(
          buildAdminTestApp(
            authenticated: true,
            user: _staff,
            staffService: api.service,
            initialRoute: AppRoutes.staffCheckIn,
          ),
        );
        await pumpRoute(tester);
        await tester.enterText(find.byKey(const Key('checkInCode')), 'BK-PAID');
        await tester.tap(find.text('Find ticket'));
        await pumpRoute(tester);
        expect(find.byKey(const Key('checkInTicket')), findsOneWidget);

        api.bookings.first['checkedInAt'] = DateTime.now().toIso8601String();
        await tester.tap(find.byKey(const Key('checkInButton')));
        await pumpRoute(tester);
        expect(find.textContaining('already checked in'), findsOneWidget);
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byKey(const Key('checkInTicket')), findsNothing);
        expect(find.byKey(const Key('checkInButton')), findsNothing);
        expect(find.text(inception.title), findsNothing);
        expect(find.text('khach@test.local'), findsNothing);
      },
    );

    testWidgets('Staff check tickets in from the app', (tester) async {
      final api = _BookingApi();
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          user: _staff,
          staffService: api.service,
        ),
      );
      await pumpRoute(tester);

      await tester.tap(find.byKey(const Key('openCheckIn')));
      await pumpRoute(tester);
      expect(find.text('Ticket check-in'), findsWidgets);

      await tester.enterText(find.byKey(const Key('checkInCode')), 'BK-PAID');
      await tester.tap(find.text('Find ticket'));
      await pumpRoute(tester);
      await tester.ensureVisible(find.byKey(const Key('checkInButton')));
      await tester.tap(find.byKey(const Key('checkInButton')));
      await pumpRoute(tester);
      expect(api.checkIns, ['BK-PAID']);
    });
  });

  testWidgets('The showtime page shows which seats are sold and used', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _BookingApi();
    await tester.pumpWidget(
      buildAdminTestApp(
        authenticated: true,
        user: _staff,
        staffService: api.service,
        initialRoute: AppRoutes.staffRecord('showtimes', 11),
      ),
    );
    await pumpRoute(tester);

    expect(
      find.text('3 of 6 seats sold • 1 checked in • 1 awaiting payment'),
      findsOneWidget,
    );
    expect(find.text('Checked in (1)'), findsOneWidget);
    expect(find.text('Free (2)'), findsOneWidget);

    // A1 belongs to the paid booking: tapping it opens the booking.
    await tester.tap(find.byKey(const ValueKey('showtimeSeat-A1')));
    await pumpRoute(tester);
    expect(find.text('Booking details'), findsWidgets);
    expect(find.text('Booking: BK-PAID'), findsOneWidget);
  });

  group('Customer ticket', () {
    testWidgets('A paid booking carries a QR code to check in with', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: FakeBookingRepository(
            bookings: [
              bookingFixture(status: BookingStatus.confirmed, paymentId: 501),
            ],
          ),
          initialRoute: AppRoutes.bookingDetail(101),
        ),
      );
      await pumpRoute(tester);

      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(find.byKey(const Key('ticketQr')), findsOneWidget);
      expect(
        find.text('Show this QR code at the cinema to check in.'),
        findsOneWidget,
      );
      expect(qr.semanticsLabel, contains('BK-20261005193000-111111'));
    });

    testWidgets('A used ticket says when it was checked in', (tester) async {
      final at = DateTime.now().subtract(const Duration(minutes: 5));
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: FakeBookingRepository(
            bookings: [
              bookingFixture(
                status: BookingStatus.confirmed,
                paymentId: 501,
                checkedInAt: at,
              ),
            ],
          ),
          initialRoute: AppRoutes.bookingDetail(101),
        ),
      );
      await pumpRoute(tester);

      expect(find.text('Checked in'), findsWidgets);
      expect(find.textContaining('Checked in '), findsWidgets);
    });

    testWidgets('An unpaid booking has no ticket QR code', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: FakeBookingRepository(
            bookings: [bookingFixture()],
          ),
          initialRoute: AppRoutes.bookingDetail(101),
        ),
      );
      await pumpRoute(tester);

      expect(find.byType(QrImageView), findsNothing);
    });
  });
}

Map<String, Object?> _booking(
  int id,
  String code,
  String status,
  List<(int, String)> seats,
) => {
  'id': id,
  'bookingCode': code,
  'userId': 101,
  'customerEmail': 'khach@test.local',
  'showtimeId': 11,
  'status': status,
  'totalAmount': 90000 * seats.length,
  'movieTitle': inception.title,
  'showTime': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
  'checkedInAt': null,
  'createdAt': DateTime.now().toIso8601String(),
  'seats': [
    for (final (seatId, label) in seats)
      {'id': seatId * 10, 'seatId': seatId, 'seatLabel': label, 'price': 90000},
  ],
};

// Booking and showtime endpoints of the API for check-in, kept in memory.
// Showtime 11 is in room 1 (A1..A3, B1..B3): BK-PAID holds A1 and A2,
// BK-UNPAID holds B1 and BK-USED (already checked in) holds B2.
class _BookingApi {
  _BookingApi({this.legacyUsedLookup = false});

  final bool legacyUsedLookup;
  final bookings = [
    _booking(1, 'BK-PAID', 'CONFIRMED', [(1, 'A1'), (2, 'A2')]),
    _booking(2, 'BK-UNPAID', 'PENDING', [(4, 'B1')]),
    {
      ..._booking(3, 'BK-USED', 'CONFIRMED', [(5, 'B2')]),
      'checkedInAt': DateTime.now().toIso8601String(),
    },
  ];
  final checkIns = <String>[];
  final requests = <String>[];

  late final service = StaffService(
    client: ApiClient(httpClient: MockClient(_handle)),
  );

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    requests.add(path);
    final segments = request.url.pathSegments;
    if (request.method == 'POST' && path.endsWith('/check-in')) {
      final booking = bookings.firstWhere(
        (b) => b['id'] == int.parse(segments[3]),
      );
      if (booking['checkedInAt'] != null) {
        return _problem(
          409,
          'This ticket was already checked in and cannot be used again.',
        );
      }
      booking['checkedInAt'] = DateTime.now().toIso8601String();
      checkIns.add(booking['bookingCode'] as String);
      return _json(booking);
    }
    if (path.startsWith('/api/v1/bookings/code/')) {
      final code = Uri.decodeComponent(segments.last).toUpperCase();
      final booking = bookings.where((b) => b['bookingCode'] == code);
      if (!legacyUsedLookup &&
          booking.isNotEmpty &&
          booking.first['checkedInAt'] != null) {
        return _problem(
          409,
          'This ticket was already checked in and cannot be used again.',
        );
      }
      return booking.isEmpty
          ? _problem(404, 'No booking has the code $code.')
          : _json(booking.first);
    }
    if (path == '/api/v1/bookings/showtime/11/seats') {
      return _json([
        for (final booking in bookings)
          for (final seat in booking['seats'] as List)
            {
              'seatId': (seat as Map)['seatId'],
              'seatLabel': seat['seatLabel'],
              'bookingId': booking['id'],
              'bookingCode': booking['bookingCode'],
              'status': booking['status'],
              'checkedInAt': booking['checkedInAt'],
            },
      ]);
    }
    if (segments.length == 4 && path.startsWith('/api/v1/bookings/')) {
      return _json(
        bookings.firstWhere((b) => b['id'] == int.parse(segments[3])),
      );
    }
    if (path == '/api/showtimes/11') {
      final start = DateTime.now().add(const Duration(hours: 1));
      return _json({
        'id': 11,
        'movieId': inception.id,
        'roomId': 1,
        'startTime': start.toIso8601String(),
        'endTime': start.add(const Duration(hours: 2)).toIso8601String(),
        'price': 90000,
        'status': 'OPEN',
      });
    }
    if (path == '/api/seats/room/1') {
      return _json([
        for (final (index, row) in ['A', 'B'].indexed)
          for (var number = 1; number <= 3; number++)
            {
              'id': index * 3 + number,
              'roomId': 1,
              'seatRow': row,
              'seatNumber': number,
              'seatType': 'NORMAL',
            },
      ]);
    }
    // Payments of a booking and other lists: none.
    return _json({
      'items': const [],
      'pageNumber': 1,
      'pageSize': 10,
      'totalCount': 0,
      'totalPages': 0,
    });
  }

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  http.Response _problem(int status, String detail) =>
      _json({'title': 'Error', 'status': status, 'detail': detail}, status);
}
