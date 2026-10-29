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

  testWidgets(
    'Staff sell a member tickets: movie, showtime, seats on the map',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final posts = <Map<String, Object?>>[];
      final service = StaffService(
        client: ApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'POST' &&
                request.url.path == '/api/v1/bookings') {
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

      await tester.tap(find.text('Member account'));
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
      await tester.tap(find.text('Hold seats and take payment'));
      await pumpFrames(tester);
      await tester.tap(find.text('Confirm'));
      await pumpFrames(tester);

      final body = posts.single;
      expect(body['userId'], 101);
      expect(body['customerEmail'], 'khach@test.local');
      expect(body.containsKey('customerPhone'), isFalse);
      expect(body['showtimeId'], 11);
      expect(
        {for (final seat in body['seats'] as List) (seat as Map)['seatId']},
        {1, 5, 6},
      );
      // The seats are held; the counter goes on to take the money.
      expect(find.text('Take payment'), findsWidgets);
    },
  );

  testWidgets('A walk-in guest needs no account, email or phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final posts = <Map<String, Object?>>[];
    final service = StaffService(
      client: ApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path == '/api/v1/bookings') {
            posts.add((jsonDecode(request.body) as Map).cast());
          }
          return _json({
            'id': 78,
            'bookingCode': 'BK-WALKIN',
            'showtimeId': 11,
            'status': 'PENDING',
            'totalAmount': 90000,
            'customerPhone': '0901 234 567',
            'createdAt': DateTime.now().toIso8601String(),
            'seats': const [],
          });
        }),
      ),
    );
    await tester.pumpWidget(
      buildAdminTestApp(
        authenticated: true,
        user: _staff,
        staffService: service,
        catalogRepository: FakeCatalogRepository(
          showtimes: [showtimeFixture()],
          seatMap: ShowtimeSeatsData.fromOccupied(
            seats: const [
              Seat(id: 1, roomId: 1, row: 'A', number: 1, type: 'NORMAL'),
            ],
            occupiedSeatIds: const [],
          ),
        ),
        initialRoute: AppRoutes.staffCreateBooking,
      ),
    );
    await pumpRoute(tester);

    expect(find.text('Customer account ID'), findsNothing);
    await tester.tap(find.byKey(const Key('bookingMovie')));
    await pumpRoute(tester);
    await tester.tap(find.text(inception.title).last);
    await pumpRoute(tester);
    await tester.tap(find.byKey(ValueKey('bookingShowtime-${inception.id}')));
    await pumpRoute(tester);
    await tester.tap(find.textContaining('Room 1 •').last);
    await pumpRoute(tester);
    await tester.tap(find.byKey(const ValueKey('counterSeat-A1')));

    // A phone number has to look like one.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone (optional)'),
      'call me',
    );
    await tester.tap(find.text('Hold seats and take payment'));
    await pumpFrames(tester);
    expect(find.text('Enter 8 to 15 digits.'), findsOneWidget);
    expect(posts, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone (optional)'),
      '0901 234 567',
    );
    await tester.tap(find.text('Hold seats and take payment'));
    await pumpFrames(tester);
    await tester.tap(find.text('Confirm'));
    await pumpFrames(tester);

    final body = posts.single;
    expect(body.containsKey('userId'), isFalse);
    expect(body.containsKey('customerEmail'), isFalse);
    expect(body['customerPhone'], '0901 234 567');
    expect(find.text('Walk-in guest • 0901 234 567'), findsOneWidget);
  });

  testWidgets('Cash: the change, the paid ticket and check in now', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final counter = _Counter();
    await tester.pumpWidget(
      buildAdminTestApp(
        authenticated: true,
        user: _staff,
        staffService: counter.service,
        initialRoute: AppRoutes.staffCheckout(77),
      ),
    );
    await pumpFrames(tester);

    expect(find.text('Walk-in guest • 0901 234 567'), findsOneWidget);
    expect(find.byKey(const Key('holdCountdown')), findsOneWidget);
    expect(find.byKey(const ValueKey('cashSuggestion-180000')), findsOneWidget);

    // Not enough cash cannot be taken.
    await tester.enterText(find.byKey(const Key('cashReceived')), '150000');
    await tester.pump();
    expect(find.text('Short by ${formatVnd(30000)}'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cashSuggestion-200000')));
    await tester.pump();
    expect(find.text('Change: ${formatVnd(20000)}'), findsOneWidget);

    await tester.tap(find.text('Confirm cash payment'));
    await pumpFrames(tester);
    expect(
      find.textContaining('Give back ${formatVnd(20000)}'),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirm'));
    await pumpFrames(tester);

    expect(counter.cash, {'bookingId': 77, 'amountReceived': 200000});
    expect(find.text('Paid'), findsWidgets);
    expect(find.byKey(const Key('changeToGive')), findsOneWidget);
    expect(find.byKey(const Key('ticketQr')), findsOneWidget);
    expect(find.textContaining('No email: print the ticket'), findsOneWidget);

    // The show starts in half an hour: the guest goes straight in.
    await tester.tap(find.text('Check in now'));
    await pumpFrames(tester);
    expect(counter.checkedIn, isTrue);
    expect(find.text('Paid and checked in'), findsOneWidget);
    expect(find.text('Check in now'), findsNothing);
  });

  testWidgets('Bank transfer: the QR code, then the ticket once paid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final counter = _Counter(email: 'khach@test.local');
    await tester.pumpWidget(
      buildAdminTestApp(
        authenticated: true,
        user: _staff,
        staffService: counter.service,
        initialRoute: AppRoutes.staffCheckout(77),
      ),
    );
    await pumpFrames(tester);

    await tester.tap(find.text('Bank transfer'));
    await pumpFrames(tester);
    await tester.tap(find.text('Show transfer QR'));
    await pumpFrames(tester);

    expect(counter.transfer?['bookingId'], 77);
    expect(counter.transfer?['amount'], 180000);
    expect(counter.transfer?.containsKey('userId'), isFalse);
    expect(find.byKey(const Key('transferQr')), findsOneWidget);
    expect(find.textContaining('Scan with any banking app'), findsOneWidget);

    // Not there yet when asked by hand.
    await tester.tap(find.text('Check payment'));
    await pumpFrames(tester);
    expect(find.text('The transfer has not arrived yet.'), findsOneWidget);

    // The screen keeps asking; the money arrives.
    counter.transferArrived = true;
    await tester.pump(const Duration(seconds: 3));
    await pumpFrames(tester);
    expect(counter.verifyEmails.last, 'khach@test.local');
    expect(find.byKey(const Key('ticketQr')), findsOneWidget);
    expect(find.textContaining('emailed to khach@test.local'), findsOneWidget);
    // The show is tomorrow: check-in is not open yet.
    expect(find.text('Check in now'), findsNothing);

    // Asking stopped once paid.
    final asked = counter.verifyEmails.length;
    await tester.pump(const Duration(seconds: 10));
    expect(counter.verifyEmails.length, asked);
  });
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

// The booking API behind the counter checkout: a walk-in booking that is paid
// in cash or by a bank transfer, then checked in.
class _Counter {
  _Counter({this.email})
    : showTime = email == null
          ? DateTime.now().add(const Duration(minutes: 30))
          : DateTime.now().add(const Duration(days: 1));

  final String? email;
  final DateTime showTime;
  final expiresAt = DateTime.now().add(const Duration(minutes: 10));
  String status = 'PENDING';
  bool checkedIn = false;
  bool transferArrived = false;
  Map<String, Object?>? cash;
  Map<String, Object?>? transfer;
  final verifyEmails = <String?>[];

  late final service = StaffService(
    client: ApiClient(
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST' && path == '/api/v1/payments/cash') {
          cash = (jsonDecode(request.body) as Map).cast();
          status = 'CONFIRMED';
          return _json(_payment('CASH'));
        }
        if (path == '/api/v1/payments/payos/checkout') {
          transfer = (jsonDecode(request.body) as Map).cast();
          return _json({
            'paymentId': 9,
            'orderCode': 77,
            'checkoutUrl': 'https://pay.example/77',
            'qrCode': '00020101021238570010A00000072777',
          });
        }
        if (path == '/api/v1/payments/payos/77/verify') {
          verifyEmails.add(request.url.queryParameters['recipientEmail']);
          if (transferArrived) status = 'CONFIRMED';
          return _json(_payment('PAYOS'));
        }
        if (path == '/api/v1/bookings/77/check-in') {
          checkedIn = true;
          return _json(_booking());
        }
        return _json(_booking());
      }),
    ),
  );

  Map<String, Object?> _payment(String method) => {
    'id': 9,
    'paymentCode': 'PAY-1',
    'bookingId': 77,
    'amount': 180000,
    'method': method,
    'status': status == 'CONFIRMED' ? 'SUCCESS' : 'PENDING',
    'createdAt': DateTime.now().toIso8601String(),
  };

  Map<String, Object?> _booking() => {
    'id': 77,
    'bookingCode': 'BK-COUNTER',
    'customerEmail': email,
    'customerPhone': email == null ? '0901 234 567' : null,
    'showtimeId': 11,
    'movieTitle': inception.title,
    'showTime': showTime.toIso8601String(),
    'status': status,
    'totalAmount': 180000,
    'expiresAt': status == 'PENDING' ? expiresAt.toIso8601String() : null,
    'checkedInAt': checkedIn ? DateTime.now().toIso8601String() : null,
    'createdAt': DateTime.now().toIso8601String(),
    'seats': [
      {'id': 1, 'seatId': 1, 'seatLabel': 'A1', 'price': 90000},
      {'id': 2, 'seatId': 2, 'seatLabel': 'A2', 'price': 90000},
    ],
  };
}
