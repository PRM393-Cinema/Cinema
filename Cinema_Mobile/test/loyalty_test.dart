import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/loyalty.dart';
import 'package:cinema_fe/data/models/paged_result.dart';
import 'package:cinema_fe/data/models/seat.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:cinema_fe/features/profile/widgets/membership_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

Map<String, Object?> _cardJson({
  int userId = 3,
  int points = 120,
  String tier = 'MEMBER',
  double spend = 500000,
}) => {
  'userId': userId,
  'points': points,
  'pointValue': 1000,
  'tier': tier,
  'lifetimeSpend': spend,
  'earnRatePercent': 5,
  'nextTier': 'VIP',
  'nextTierSpend': 2000000,
  'transactions': [
    {
      'id': 2,
      'type': 'EARN',
      'points': 20,
      'bookingId': 9,
      'note': 'BK-20261027',
      'createdAt': '2026-10-27T19:00:00',
    },
    {
      'id': 1,
      'type': 'ADJUST',
      'points': 100,
      'note': 'Welcome gift',
      'createdAt': '2026-10-20T10:00:00',
    },
  ],
};

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('A card reads points, tier and what can be used', () {
    final card = LoyaltyCard.fromJson(_cardJson());
    expect(card.tier, MemberTier.member);
    expect(card.pointsValue, 120000);
    expect(card.progress, 0.25);
    expect(card.history.first.pointsText, '+20');
    // Half of 90.000 ₫ is 45 points; all 120 fit in a 500.000 ₫ order.
    expect(card.usableOn(90000), 45);
    expect(card.usableOn(500000), 120);
    expect(maxRedeemablePoints(0), 0);
  });

  testWidgets('The profile shows the membership card', (tester) async {
    final bookings = FakeBookingRepository()
      ..loyalty = LoyaltyCard.fromJson(_cardJson());
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        bookingRepository: bookings,
        initialRoute: AppRoutes.profile,
      ),
    );
    await pumpRoute(tester);

    expect(find.text('120 points'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('${formatVnd(1500000)} to VIP'), findsOneWidget);
    expect(find.text('Changed by the cinema'), findsOneWidget);
    expect(find.text('+100'), findsOneWidget);
  });

  testWidgets('An empty membership card stays compact on a narrow screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: MembershipCard(
                card: LoyaltyCard.fromJson({
                  ..._cardJson(points: 0, spend: 0),
                  'transactions': <Object?>[],
                }),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('0 points'), findsOneWidget);
    expect(find.text('${formatVnd(2000000)} to VIP'), findsOneWidget);
    expect(find.text('Points history'), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('membershipCard'))).height,
      lessThan(180),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('A member pays part of the tickets with points', (tester) async {
    final bookings = FakeBookingRepository()
      ..loyalty = LoyaltyCard.fromJson(_cardJson());
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

    // One standard seat (90.000 ₫): at most half, 45 points.
    expect(find.text('Use 45 points'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('usePoints')));
    await tester.tap(find.byKey(const Key('usePoints')));
    await tester.pump();
    expect(find.text('−${formatVnd(45000)}'), findsOneWidget);
    expect(find.text(formatVnd(45000)), findsOneWidget);

    await tester.ensureVisible(find.text('Confirm Booking'));
    await tester.tap(find.text('Confirm Booking'));
    await pumpFrames(tester);
    expect(bookings.updateCalls.single.usePoints, 45);
  });

  testWidgets('The counter finds a member by phone and uses their points', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final posts = <Map<String, Object?>>[];
    final lookups = <String>[];
    final service = StaffService(
      client: ApiClient(
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path == '/api/v1/auth/members') {
            lookups.add(request.url.queryParameters['phone']!);
            return _json([
              {
                'userId': 7,
                'email': 'member7@test.local',
                'fullName': 'Tran Thi Member',
                'phone': '0909 111 222',
              },
            ]);
          }
          if (path == '/api/v1/loyalty/users/7') {
            return _json(_cardJson(userId: 7, points: 30, tier: 'VIP'));
          }
          if (request.method == 'POST' && path == '/api/v1/bookings') {
            posts.add((jsonDecode(request.body) as Map).cast());
            return _json({
              'id': 79,
              'bookingCode': 'BK-MEMBER',
              'userId': 7,
              'showtimeId': 11,
              'status': 'PENDING',
              'totalAmount': 60000,
              'pointsUsed': 30,
              'pointsDiscount': 30000,
              'createdAt': DateTime.now().toIso8601String(),
              'seats': const [],
            });
          }
          // Concessions, promotion quotes: nothing.
          return _json(path.endsWith('/quote') ? {'discount': 0} : []);
        }),
      ),
    );
    final catalog = FakeCatalogRepository(
      showtimes: [
        showtimeFixture(seatPrices: const {'NORMAL': 90000}),
      ],
      seatMap: ShowtimeSeatsData.fromOccupied(
        seats: [
          for (var number = 1; number <= 4; number++)
            Seat(
              id: number,
              roomId: 1,
              row: 'A',
              number: number,
              type: 'NORMAL',
            ),
        ],
        occupiedSeatIds: const [],
      ),
    );
    await tester.pumpWidget(
      buildAdminTestApp(
        authenticated: true,
        user: AuthUser.fromJson({
          ...customerUser.toJson(),
          'roles': ['ROLE_STAFF'],
        }),
        staffService: service,
        catalogRepository: catalog,
        initialRoute: AppRoutes.staffCreateBooking,
      ),
    );
    await pumpRoute(tester);

    await tester.tap(find.text('Member account'));
    await pumpRoute(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Find by phone'),
      '0909111222',
    );
    await tester.tap(find.byKey(const Key('findMember')));
    await pumpRoute(tester);
    expect(lookups, ['0909111222']);
    expect(find.text('Tran Thi Member · 30 points'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '7'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'member7@test.local'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('bookingMovie')));
    await pumpRoute(tester);
    await tester.tap(find.text(inception.title).last);
    await pumpRoute(tester);
    await tester.tap(find.byKey(ValueKey('bookingShowtime-${inception.id}')));
    await pumpRoute(tester);
    await tester.tap(find.textContaining('Room 1 •').last);
    await pumpRoute(tester);
    await tester.tap(find.byKey(const ValueKey('counterSeat-A1')));
    await pumpRoute(tester);

    // 90.000 ₫: up to 45 points, the member has 30.
    expect(find.text('Use 30 points'), findsOneWidget);
    await tester.tap(find.byKey(const Key('usePoints')));
    await tester.pump();
    expect(
      find.text('1 seat(s) selected · ${formatVnd(60000)}'),
      findsOneWidget,
    );

    await tester.tap(find.text('Hold seats and take payment'));
    await pumpFrames(tester);
    await tester.tap(find.text('Confirm'));
    await pumpFrames(tester);
    final body = posts.single;
    expect(body['userId'], 7);
    expect(body['customerEmail'], 'member7@test.local');
    expect(body['usePoints'], 30);
  });

  testWidgets('Admin sees members with their points and adds points', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final adjusted = <Map<String, Object?>>[];
    var points = 120;
    final service = StaffService(
      client: ApiClient(
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path == '/api/v1/loyalty/accounts') {
            expect(request.url.queryParameters['userIds'], '3');
            return _json([_cardJson(points: points)]);
          }
          if (path == '/api/v1/loyalty/users/3/adjust') {
            final body = (jsonDecode(request.body) as Map)
                .cast<String, Object?>();
            adjusted.add(body);
            points += body['points']! as int;
          }
          return _json(_cardJson(points: points));
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
        authRepository: _MembersAuth(),
        staffService: service,
        initialRoute: AppRoutes.adminMembers,
      ),
    );
    await pumpRoute(tester);

    expect(find.text(customerUser.displayName), findsOneWidget);
    expect(find.text('120 pts'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('member-3')));
    await pumpRoute(tester);
    expect(find.text('120 points'), findsOneWidget);

    Finder field(String key) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(TextFormField),
    );
    await tester.tap(find.byKey(const Key('saveAdjustPoints')));
    await pumpRoute(tester);
    expect(find.text('Enter the points to add or take away.'), findsOneWidget);
    expect(find.text('Enter a reason.'), findsOneWidget);

    await tester.enterText(field('adjustPointsField'), '-20');
    await tester.enterText(field('adjustNoteField'), 'Wrong ticket');
    await tester.tap(find.byKey(const Key('saveAdjustPoints')));
    await pumpFrames(tester);
    expect(adjusted.single, {'points': -20, 'note': 'Wrong ticket'});
    await pumpRoute(tester);
    expect(find.text('100 points'), findsOneWidget);
  });
}

class _MembersAuth extends FakeAuthRepository {
  @override
  Future<PagedResult<AuthUser>> users({
    int page = 1,
    String? keyword,
    String? role,
    bool? enabled,
  }) async {
    expect(role, 'ROLE_CUSTOMER');
    return PagedResult(
      items: [customerUser],
      pageNumber: 1,
      totalPages: 1,
      totalCount: 1,
    );
  }
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
