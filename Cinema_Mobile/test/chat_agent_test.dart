import 'dart:convert';

import 'package:cinema_fe/core/network/access_token_provider.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/session/session_state.dart';
import 'package:cinema_fe/data/models/seat.dart';
import 'package:cinema_fe/data/services/chat_service.dart';
import 'package:cinema_fe/features/booking/screens/booking_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/test_app.dart';
import 'support/fakes.dart';

Map<String, Object?> proposal({
  List<int> seats = const [1],
  double total = 90000,
  bool expired = false,
}) => {
  'movieId': 1,
  'showtimeId': 11,
  'movieTitle': 'Inception',
  'seatIds': seats,
  'total': total,
  'expiresAt': DateTime.now()
      .add(Duration(minutes: expired ? -1 : 5))
      .toUtc()
      .toIso8601String(),
};

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Signed-in chat uses the protected endpoint and keeps credentials out of the body', () async {
    final requests = <http.Request>[];
    final service = ChatService(
      client: ApiClient(
        tokenProvider: _Token(),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('{"message":"VIP"}', 200);
        }),
      ),
    );
    await service.replyWithActions([
      const ChatMessage(role: 'user', content: 'My tier'),
    ], authenticated: true);
    expect(requests.single.url.path, '/api/v1/chat/account');
    expect(requests.single.headers['Authorization'], 'Bearer customer-token');
    expect(requests.single.body, isNot(contains('customer-token')));
    requests.clear();
    await service.reply([const ChatMessage(role: 'user', content: 'Movies')]);
    expect(requests.single.url.path, '/api/v1/chat');
    expect(requests.single.headers['Authorization'], isNull);
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'At $width proposal is read-only until explicit confirmation; repeated clicks create one hold',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final bookings = FakeBookingRepository();
        final catalog = FakeCatalogRepository();
        final service = ChatService(
          client: ApiClient(
            httpClient: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'message': 'Ready to review',
                  'booking': proposal(),
                }),
                200,
              ),
            ),
          ),
        );
        await tester.pumpWidget(
          buildTestApp(
            authenticated: true,
            bookingRepository: bookings,
            catalogRepository: catalog,
            chatService: service,
          ),
        );
        await pumpRoute(tester);
        await tester.tap(find.byKey(const Key('openCinemaChat')));
        await pumpRoute(tester);
        await tester.enterText(
          find.byKey(const Key('cinemaChatInput')),
          'Book A1',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('sendCinemaChat')));
        await pumpRoute(tester);
        expect(bookings.createCalls, isEmpty);
        final review = find.byKey(const Key('reviewChatBooking'));
        await tester.ensureVisible(review);
        await tester.tap(review);
        await pumpRoute(tester);
        final confirm = find.byKey(const Key('confirmChatBooking'));
        await tester.ensureVisible(confirm);
        expect(bookings.createCalls, isEmpty);
        await tester.tap(confirm);
        await tester.tap(confirm, warnIfMissed: false);
        await pumpRoute(tester);
        expect(bookings.createCalls, hasLength(1));
        expect(bookings.createCalls.single.seatIds, [1]);
        expect(catalog.seatMapLoads, 1);
        expect(find.byType(BookingSummaryScreen), findsNothing);
        expect(find.byKey(const Key('chatSeatBooking')), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scenario in ['occupied', 'price changed', 'expired']) {
    testWidgets('$scenario proposals never create a booking', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final bookings = FakeBookingRepository();
      final service = ChatService(
        client: ApiClient(
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'message': 'Review',
                'booking': proposal(
                  seats: scenario == 'occupied' ? [2] : [1],
                  total: scenario == 'price changed' ? 1 : 90000,
                  expired: scenario == 'expired',
                ),
              }),
              200,
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: bookings,
          chatService: service,
        ),
      );
      await pumpRoute(tester);
      await tester.tap(find.byKey(const Key('openCinemaChat')));
      await pumpRoute(tester);
      await tester.enterText(
        find.byKey(const Key('cinemaChatInput')),
        'Book seats',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('sendCinemaChat')));
      await pumpRoute(tester);
      final review = find.byKey(const Key('reviewChatBooking'));
      await tester.ensureVisible(review);
      await tester.tap(review);
      await pumpRoute(tester);
      expect(
        find.text(
          scenario == 'expired'
              ? 'Đề xuất đã hết hạn. Hãy chọn lại ghế.'
              : 'Ghế hoặc giá đã thay đổi. Hãy chọn lại ghế.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('confirmChatBooking')), findsNothing);
      expect(bookings.createCalls, isEmpty);
    });
  }

  testWidgets(
    'Booking form leads to live adjacent seats and holds inside chat',
    (tester) async {
      final vietnam = DateTime.now().toUtc().add(const Duration(hours: 7));
      final date = vietnam.toIso8601String().substring(0, 10);
      final requests = <Map<String, dynamic>>[];
      final service = ChatService(
        client: ApiClient(
          httpClient: MockClient((request) async {
            requests.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              jsonEncode(
                requests.length == 1
                    ? {
                        'message': 'Bổ sung thông tin',
                        'bookingForm': {
                          'movie': 'Inception',
                          'date': date,
                          'tickets': 2,
                        },
                      }
                    : {
                        'message': '[Chọn ghế](/showtimes/11/seats)',
                        'showtimeTickets': {'/showtimes/11/seats': 2},
                      },
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      final catalog = FakeCatalogRepository(
        seatMap: ShowtimeSeatsData.fromOccupied(
          seats: const [
            Seat(id: 1, roomId: 1, row: 'A', number: 1, type: 'NORMAL'),
            Seat(id: 2, roomId: 1, row: 'A', number: 2, type: 'NORMAL'),
            Seat(id: 3, roomId: 1, row: 'A', number: 3, type: 'NORMAL'),
          ],
          occupiedSeatIds: [1],
        ),
      );
      final bookings = FakeBookingRepository();
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          catalogRepository: catalog,
          bookingRepository: bookings,
          chatService: service,
        ),
      );
      await pumpRoute(tester);
      await tester.tap(find.byKey(const Key('openCinemaChat')));
      await pumpRoute(tester);
      await tester.enterText(
        find.byKey(const Key('cinemaChatInput')),
        'Đặt giúp 2 vé Inception hôm nay',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('sendCinemaChat')));
      await pumpRoute(tester);
      final time = find.byKey(const Key('chatBookingTime'));
      await tester.ensureVisible(time);
      await tester.enterText(time, '20:00');
      final search = find.text('Tìm suất chiếu');
      await tester.ensureVisible(search);
      await tester.tap(search);
      await pumpRoute(tester);
      final request =
          (requests.last['messages'] as List).last['content'] as String;
      expect(request, contains('2 vé'));
      expect(request, contains('Inception'));
      expect(request, contains('20:00'));
      await tester.tap(find.widgetWithText(TextButton, 'Chọn ghế'));
      await pumpRoute(tester);
      final suggested = find.text('Gợi ý A2, A3');
      await tester.ensureVisible(suggested);
      await tester.tap(suggested);
      await pumpRoute(tester);
      final review = find.text('Xem lại đặt vé');
      await tester.ensureVisible(review);
      await tester.tap(review);
      await pumpRoute(tester);
      expect(bookings.createCalls, isEmpty);
      final confirm = find.byKey(const Key('confirmChatBooking'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await pumpRoute(tester);
      expect(bookings.createCalls.single.seatIds, [2, 3]);
      expect(bookings.checkoutBookingIds, isEmpty);
      expect(find.byType(BookingSummaryScreen), findsNothing);
      expect(find.byKey(const Key('chatSeatBooking')), findsOneWidget);
      final payment = find.text('Tạo link PayOS');
      await tester.ensureVisible(payment);
      await tester.tap(payment);
      await pumpRoute(tester);
      expect(bookings.checkoutBookingIds, hasLength(1));
      expect(find.text('Mở PayOS'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Changing identity clears account messages and pending proposals',
    (tester) async {
      final session = SessionState();
      final bookings = FakeBookingRepository();
      final service = ChatService(
        client: ApiClient(
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'message': 'Private account result',
                'booking': proposal(),
              }),
              200,
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        buildTestApp(
          session: session,
          authenticated: true,
          bookingRepository: bookings,
          chatService: service,
        ),
      );
      await pumpRoute(tester);
      await tester.tap(find.byKey(const Key('openCinemaChat')));
      await pumpRoute(tester);
      await tester.enterText(
        find.byKey(const Key('cinemaChatInput')),
        'My account',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('sendCinemaChat')));
      await pumpRoute(tester);
      expect(find.text('Private account result'), findsOneWidget);
      session.clear();
      await pumpRoute(tester);
      expect(find.text('Private account result'), findsNothing);
      expect(find.byKey(const Key('reviewChatBooking')), findsNothing);
      expect(bookings.createCalls, isEmpty);
    },
  );
}

class _Token implements AccessTokenProvider {
  @override
  Future<String?> accessToken() async => 'customer-token';
  @override
  Future<String?> refreshAccessToken({required String failedToken}) async =>
      null;
  @override
  Future<void> expireSession({required String message}) async {}
}
