import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/widgets/cinema_account_widgets.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

const _computer = Size(1440, 900);
const _phone = Size(390, 844);

void _useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

final _header = find.byKey(const Key('webHeader'));

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('Customer website on a computer', () {
    testWidgets('Navigation is at the top, without the tab bar', (
      tester,
    ) async {
      _useWindow(tester, _computer);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: FakeBookingRepository(
            bookings: [bookingFixture()],
          ),
        ),
      );
      await pumpRoute(tester);

      expect(_header, findsOneWidget);
      expect(find.byType(CinemaNavigationBar), findsNothing);
      expect(
        find.descendant(of: _header, matching: find.text('Movies')),
        findsOneWidget,
      );
      expect(find.text(customerUser.displayName), findsOneWidget);

      await tester.tap(
        find.descendant(of: _header, matching: find.text('My tickets')),
      );
      await pumpRoute(tester);
      expect(find.text('My Bookings'), findsOneWidget);
      expect(_header, findsOneWidget);

      await tester.tap(find.byKey(const Key('webHeaderAccount')));
      await pumpRoute(tester);
      expect(find.text('Account settings'), findsOneWidget);
    });

    testWidgets('Guests can sign in or sign up from the top bar', (
      tester,
    ) async {
      _useWindow(tester, _computer);
      await tester.pumpWidget(buildTestApp());
      await pumpRoute(tester);

      expect(find.byKey(const Key('webHeaderRegister')), findsOneWidget);
      expect(
        find.descendant(of: _header, matching: find.text('My tickets')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('webHeaderSignIn')));
      await pumpRoute(tester);
      // Sign-in pages keep their own full-screen design.
      expect(find.byKey(const Key('loginTitle')), findsOneWidget);
      expect(_header, findsNothing);
    });

    testWidgets('Seat map with the order summary next to it', (tester) async {
      _useWindow(tester, _computer);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          initialRoute: AppRoutes.seatSelection(11),
        ),
      );
      await pumpRoute(tester);

      expect(find.text('Your seats'), findsOneWidget);
      expect(find.text('Choose your seats on the map.'), findsOneWidget);
      await tester.tap(find.text('3').first);
      await tester.pump();
      expect(find.text('A3'), findsOneWidget);

      final summary = tester.getTopLeft(find.text('Your seats'));
      final screen = tester.getTopLeft(find.text('SCREEN'));
      expect(summary.dx, greaterThan(screen.dx));
    });

    testWidgets('Booking details in two columns', (tester) async {
      _useWindow(tester, _computer);
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

      final ticket = tester.getTopLeft(find.text('Your booking'));
      final payment = tester.getTopLeft(find.text('Payment Summary'));
      expect(payment.dx, greaterThan(ticket.dx + 400));
      expect((payment.dy - ticket.dy).abs(), lessThan(40));
      expect(find.text('Request refund'), findsOneWidget);
    });

    testWidgets('Staff accounts get no customer navigation', (tester) async {
      _useWindow(tester, _computer);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          user: AuthUser.fromJson({
            ...customerUser.toJson(),
            'roles': ['ROLE_STAFF'],
          }),
        ),
      );
      await pumpRoute(tester);

      expect(find.byKey(const Key('managementAccountTitle')), findsOneWidget);
      expect(_header, findsNothing);
    });
  });

  group('Customer app on a phone', () {
    testWidgets('Tab bar at the bottom, no website navigation', (tester) async {
      _useWindow(tester, _phone);
      await tester.pumpWidget(buildTestApp(authenticated: true));
      await pumpRoute(tester);

      expect(_header, findsNothing);
      expect(find.byType(CinemaNavigationBar), findsOneWidget);
    });

    testWidgets('Seat map with the total in a bottom bar', (tester) async {
      _useWindow(tester, _phone);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          initialRoute: AppRoutes.seatSelection(11),
        ),
      );
      await pumpRoute(tester);

      expect(find.text('Your seats'), findsNothing);
      expect(find.text('0 seat(s)'), findsOneWidget);
    });
  });

  group('Admin website', () {
    testWidgets('Pages line up with their title next to the navigation', (
      tester,
    ) async {
      _useWindow(tester, _computer);
      await tester.pumpWidget(
        buildAdminTestApp(
          authenticated: true,
          user: AuthUser.fromJson({
            ...customerUser.toJson(),
            'roles': ['ROLE_ADMIN'],
          }),
          staffService: _rooms(),
          initialRoute: AppRoutes.adminRooms,
        ),
      );
      await pumpRoute(tester);

      final title = tester.getTopLeft(find.text('Rooms').last);
      final add = tester.getTopLeft(find.byKey(const Key('addRoomButton')));
      expect(add.dx, title.dx);

      // Room cards in two columns.
      final first = tester.getTopLeft(find.text('Room 1'));
      final second = tester.getTopLeft(find.text('Room 2'));
      expect(second.dy, first.dy);
      expect(second.dx, greaterThan(first.dx + 400));
    });
  });
}

StaffService _rooms() => StaffService(
  client: ApiClient(
    httpClient: MockClient((request) async {
      final items = request.url.path.startsWith('/api/rooms')
          ? [
              for (var id = 1; id <= 4; id++)
                {'id': id, 'name': 'Room $id', 'totalSeats': 40},
            ]
          : <Object>[];
      return http.Response(
        jsonEncode({
          'items': items,
          'pageNumber': 1,
          'pageSize': 10,
          'totalCount': items.length,
          'totalPages': 1,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  ),
);
