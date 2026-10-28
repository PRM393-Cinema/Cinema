import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/models/promotion.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('A booking reads its discount', () {
    final booking = Booking.fromJson({
      'id': 1,
      'bookingCode': 'BK-1',
      'showtimeId': 1,
      'status': 'PENDING',
      'totalAmount': 150000,
      'discountAmount': 30000,
      'promotionCode': 'DUO30K',
      'promotionName': 'Duo deal',
      'createdAt': DateTime.now().toIso8601String(),
      'seats': const [],
    });
    expect(booking.hasDiscount, isTrue);
    expect(booking.discountText, '−${formatVnd(30000)} (Duo deal)');
  });

  test('A promotion describes its discount and conditions', () {
    final promotion = Promotion.fromJson({
      'id': 1,
      'code': null,
      'name': 'Happy Tuesday',
      'discountType': 'PERCENT',
      'discountValue': 20,
      'maxDiscount': 50000,
      'minTickets': 2,
      'daysOfWeek': [2],
      'usedCount': 0,
      'active': true,
    });
    expect(promotion.isAutomatic, isTrue);
    expect(
      promotion.discountText,
      '20% off tickets, up to ${formatVnd(50000)}',
    );
    expect(promotion.conditionsText, 'From 2 tickets · Tue');
  });

  testWidgets('The summary takes off the automatic deal or a promo code', (
    tester,
  ) async {
    final bookings = FakeBookingRepository()
      ..automaticDeal = const PromotionQuote(
        promotionId: 1,
        name: 'Happy Tuesday',
        discount: 18000,
      )
      ..promoCodes['WELCOME10'] = const PromotionQuote(
        promotionId: 2,
        code: 'WELCOME10',
        name: 'Welcome',
        discount: 9000,
      );
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

    // One standard seat (90.000) with the automatic 18.000 off.
    expect(find.text('Applied automatically'), findsOneWidget);
    expect(find.text(formatVnd(72000)), findsOneWidget);

    Finder codeField() => find.descendant(
      of: find.byKey(const Key('promoCodeField')),
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(codeField());
    await tester.enterText(codeField(), 'nope');
    await tester.tap(find.byKey(const Key('applyPromoCode')));
    await pumpRoute(tester);
    expect(find.text('Promo code NOPE is not valid.'), findsOneWidget);
    expect(find.text(formatVnd(72000)), findsOneWidget);

    // A code replaces the automatic deal: one promotion per booking.
    await tester.enterText(codeField(), ' welcome10 ');
    await tester.tap(find.byKey(const Key('applyPromoCode')));
    await pumpRoute(tester);
    expect(find.text('Code WELCOME10'), findsOneWidget);
    expect(find.text(formatVnd(81000)), findsOneWidget);

    await tester.ensureVisible(find.text('Confirm Booking'));
    await tester.tap(find.text('Confirm Booking'));
    await pumpFrames(tester);
    expect(bookings.createCalls.single.promotionCode, 'WELCOME10');
  });

  testWidgets('Without a deal or a code the booking has no promotion', (
    tester,
  ) async {
    final bookings = FakeBookingRepository();
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

    expect(find.byKey(const Key('promotionApplied')), findsNothing);
    expect(bookings.quoteCodes, [null]);
    await tester.ensureVisible(find.text('Confirm Booking'));
    await tester.tap(find.text('Confirm Booking'));
    await pumpFrames(tester);
    expect(bookings.createCalls.single.promotionCode, isNull);
  });

  testWidgets('Admin adds a promo code', (tester) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final posted = <Map<String, Object?>>[];
    final promotions = <Map<String, Object?>>[
      {
        'id': 1,
        'code': null,
        'name': 'Happy Tuesday',
        'discountType': 'PERCENT',
        'discountValue': 20,
        'minTickets': 1,
        'daysOfWeek': [2],
        'usedCount': 12,
        'active': true,
      },
      {
        'id': 2,
        'code': 'OLD5',
        'name': 'Old code',
        'discountType': 'AMOUNT',
        'discountValue': 5000,
        'minTickets': 1,
        'daysOfWeek': <int>[],
        'usageLimit': 10,
        'usedCount': 10,
        'active': true,
      },
    ];
    final service = StaffService(
      client: ApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'POST') {
            final body = (jsonDecode(request.body) as Map)
                .cast<String, Object?>();
            posted.add(body);
            promotions.add({...body, 'id': 9, 'usedCount': 0});
            return _json(promotions.last);
          }
          expect(request.url.queryParameters['all'], 'true');
          return _json(promotions);
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
        initialRoute: AppRoutes.adminPromotions,
      ),
    );
    await pumpRoute(tester);

    expect(find.text('Automatic'), findsOneWidget);
    expect(find.text('Used 12 times'), findsOneWidget);
    expect(find.text('Code OLD5'), findsOneWidget);
    expect(find.text('Ended'), findsOneWidget);

    await tester.tap(find.text('Add promotion'));
    await pumpRoute(tester);
    Finder field(String key) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field('promotionCodeField'), 'a!');
    await tester.enterText(field('promotionValueField'), '95');
    await tester.tap(find.byKey(const Key('savePromotion')));
    await pumpRoute(tester);
    expect(find.text('Enter a name.'), findsOneWidget);
    expect(find.text('Use 3 to 30 letters, digits, - or _.'), findsOneWidget);
    expect(find.text('Enter 1 to 90.'), findsOneWidget);

    await tester.enterText(field('promotionNameField'), 'Weekend duo');
    await tester.enterText(field('promotionCodeField'), 'duo30k');
    await tester.tap(find.text('Amount'));
    await tester.pump();
    await tester.enterText(field('promotionValueField'), '30000');
    await tester.enterText(field('promotionMinTicketsField'), '2');
    await tester.tap(find.byKey(const ValueKey('promotionDay-7')));
    await tester.tap(find.byKey(const ValueKey('promotionDay-6')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('savePromotion')));
    await tester.tap(find.byKey(const Key('savePromotion')));
    await pumpFrames(tester);

    final body = posted.single;
    expect(body['code'], 'DUO30K');
    expect(body['discountType'], 'AMOUNT');
    expect(body['discountValue'], 30000);
    expect(body['maxDiscount'], isNull);
    expect(body['minTickets'], 2);
    expect(body['daysOfWeek'], [6, 7]);
    await pumpRoute(tester);
    expect(find.byKey(const ValueKey('adminPromotion-9')), findsOneWidget);
  });
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
