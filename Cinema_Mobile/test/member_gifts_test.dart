import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/models/create_booking_request.dart';
import 'package:cinema_fe/data/models/loyalty.dart';
import 'package:cinema_fe/data/models/promotion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

class GiftBookings extends FakeBookingRepository {
  CreateBookingRequest? submitted;
  @override
  Future<Booking> updateBooking(
    int bookingId,
    CreateBookingRequest request,
  ) async {
    submitted = request;
    final confirmed = Booking.fromJson({
      'id': bookingId,
      'bookingCode': 'BK-GIFT',
      'showtimeId': request.showtimeId,
      'status': 'CONFIRMED',
      'totalAmount': 0,
      'createdAt': DateTime.now().toIso8601String(),
      'seats': <Object?>[],
    });
    bookings = [confirmed];
    return confirmed;
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('VVIP gift replaces promotion and confirms without payment', (
    tester,
  ) async {
    final bookings = GiftBookings()
      ..loyalty = LoyaltyCard.fromJson({
        'userId': 3,
        'tier': 'VVIP',
        'points': 50,
        'gifts': {'tickets': 2, 'combos': 2, 'renewsAt': '2027-04-29T10:00:00'},
      })
      ..automaticDeal = const PromotionQuote(
        promotionId: 1,
        name: 'Automatic',
        discount: 18000,
      );
    expect(bookings.loyalty!.giftTickets, 2);
    expect(bookings.loyalty!.giftRenewsAt, DateTime(2027, 4, 29, 10));
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
    await tester.tap(find.text('Room 1'));
    await tester.pump();
    await tester.tap(find.text('Continue to Seats'));
    await pumpRoute(tester);
    await tester.tap(find.text('1').last);
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await pumpRoute(tester);
    await tester.ensureVisible(find.byKey(const Key('useMemberGifts')));
    await tester.tap(find.byKey(const Key('useMemberGifts')));
    await tester.pump();
    expect(find.byKey(const Key('summaryGifts')), findsOneWidget);
    expect(find.byKey(const Key('summaryDiscount')), findsNothing);
    expect(find.byKey(const Key('usePoints')), findsNothing);
    await tester.ensureVisible(find.text('Confirm Booking'));
    await tester.tap(find.text('Confirm Booking'));
    await pumpFrames(tester);
    expect(bookings.submitted!.toJson()['useMemberGifts'], true);
    expect(bookings.submitted!.promotionCode, isNull);
    expect(bookings.submitted!.usePoints, 0);
    expect(find.text('Booking Detail'), findsOneWidget);
    expect(bookings.checkoutBookingIds, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
