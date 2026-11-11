import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/access_token_provider.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/session/session_state.dart';
import 'package:cinema_fe/data/models/seat.dart';
import 'package:cinema_fe/data/services/chat_service.dart';
import 'package:cinema_fe/features/booking/screens/booking_summary_screen.dart';
import 'package:cinema_fe/features/seat/widgets/seat_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/test_app.dart';
import 'support/fakes.dart';
import 'support/fixtures.dart';

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
        final change = find.widgetWithText(OutlinedButton, 'Đổi ghế');
        expect(tester.getSize(confirm), tester.getSize(change));
        expect(tester.getTopLeft(confirm).dy, tester.getTopLeft(change).dy);
        expect(find.byKey(const Key('cinemaChatInput')), findsOneWidget);
        expect(
          find.ancestor(
            of: confirm,
            matching: find.byKey(const Key('cinemaChatMessages')),
          ),
          findsOneWidget,
        );
        expect(bookings.createCalls, isEmpty);
        await tester.tap(confirm);
        await tester.tap(confirm, warnIfMissed: false);
        await pumpRoute(tester);
        expect(bookings.createCalls, hasLength(1));
        expect(bookings.createCalls.single.seatIds, [1]);
        expect(catalog.seatMapLoads, 1);
        expect(find.byType(BookingSummaryScreen), findsNothing);
        expect(find.byKey(const Key('chatSeatBooking')), findsOneWidget);
        final verify = find.widgetWithText(
          OutlinedButton,
          'Kiểm tra thanh toán',
        );
        final cancel = find.widgetWithText(OutlinedButton, 'Hủy giữ ghế');
        await tester.ensureVisible(cancel);
        expect(tester.getTopLeft(verify).dy, tester.getTopLeft(cancel).dy);
        expect(tester.getSize(verify), tester.getSize(cancel));
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Unconfirmed review expires in chat while other messages continue',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final bookings = FakeBookingRepository();
      var replies = 0;
      final service = ChatService(
        client: ApiClient(
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode(
                replies++ == 0
                    ? {'message': 'Ready to review', 'booking': proposal()}
                    : {'message': 'Bạn vẫn có thể nhắn tin.'},
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
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
      final input = find.byKey(const Key('cinemaChatInput'));
      final send = find.byKey(const Key('sendCinemaChat'));
      await tester.enterText(input, 'Book A1');
      await tester.pump();
      await tester.tap(send);
      await pumpRoute(tester);
      final review = find.byKey(const Key('reviewChatBooking'));
      await tester.ensureVisible(review);
      await tester.tap(review);
      await pumpRoute(tester);
      expect(find.byKey(const Key('confirmChatBooking')), findsOneWidget);

      await tester.enterText(input, 'Can I still ask about films?');
      await tester.pump();
      await tester.tap(send);
      await pumpRoute(tester);
      expect(replies, 2);
      expect(find.byKey(const ValueKey('chatMessage-3')), findsOneWidget);
      await tester.pump(const Duration(minutes: 9, seconds: 50));
      const notice = 'Đã hết thời gian xác nhận. Yêu cầu đặt vé đã được hủy.';
      expect(find.text(notice, findRichText: true), findsNothing);
      await tester.pump(const Duration(seconds: 11));
      await pumpRoute(tester);
      expect(find.byKey(const ValueKey('chatMessage-4')), findsOneWidget);
      expect(find.text(notice, findRichText: true), findsWidgets);
      expect(find.byKey(const Key('confirmChatBooking')), findsNothing);
      expect(bookings.createCalls, isEmpty);
      expect(bookings.cancelledIds, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
    'Booking form opens the full seat map and returns to chat before holding',
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
          seats: [
            for (var row = 0; row < 3; row++)
              for (var number = 1; number <= 6; number++)
                Seat(
                  id: row * 6 + number,
                  roomId: 1,
                  row: 'ABC'[row],
                  number: number,
                  type: row == 1 ? 'VIP' : 'NORMAL',
                ),
          ],
          occupiedSeatIds: [9],
        ),
      );
      final bookings = FakeBookingRepository();
      tester.view.physicalSize = const Size(1117, 690);
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
      expect(find.text('Số vé'), findsNothing);
      final time = find.byKey(const Key('chatBookingTime'));
      await tester.ensureVisible(time);
      await tester.enterText(time, '20:00');
      final composer = find.byKey(const Key('cinemaChatInput'));
      const draft = 'Còn suất nào khác không?';
      await tester.enterText(composer, draft);
      final search = find.text('Tìm suất chiếu');
      await tester.ensureVisible(search);
      await tester.tap(search);
      await pumpRoute(tester);
      expect(tester.widget<TextField>(composer).controller!.text, draft);
      final request =
          (requests.last['messages'] as List).last['content'] as String;
      expect(request, contains('2 vé'));
      expect(request, contains('Inception'));
      expect(request, contains('20:00'));
      final seatLink = find.byKey(const ValueKey('/showtimes/11/seats'));
      final picker = find.byKey(const Key('chatSeatPicker'));
      final applySeats = find.byKey(const Key('applyChatSeats'));
      final webHeader = find.byKey(const Key('webHeader'));
      expect(webHeader, findsOneWidget);
      await tester.ensureVisible(seatLink);
      expect(find.text('3 hàng · 18 ghế'), findsOneWidget);
      expect(picker, findsNothing);
      final previewSeat = tester.widget<SeatItem>(
        find.byKey(const ValueKey('preview-seat-9')),
      );
      expect(previewSeat.state, SeatItemState.booked);
      expect(previewSeat.onTap, isNull);
      await tester.tap(seatLink);
      await pumpRoute(tester);
      expect(picker, findsOneWidget);
      expect(webHeader, findsNothing);
      expect(find.text('0/2 ghế'), findsNothing);
      expect(find.byTooltip('Tăng số vé'), findsNothing);
      expect(tester.widget<FilledButton>(applySeats).onPressed, isNull);
      await tester.tap(find.byTooltip('Đóng sơ đồ ghế'));
      await pumpRoute(tester);
      expect(picker, findsNothing);
      expect(webHeader, findsOneWidget);
      expect(find.byKey(const Key('confirmChatBooking')), findsNothing);
      expect(bookings.createCalls, isEmpty);
      await tester.tap(seatLink);
      await pumpRoute(tester);
      final suggested = find.text('Gợi ý B4, B5');
      await tester.ensureVisible(suggested);
      await tester.tap(suggested);
      await pumpRoute(tester);
      await tester.tap(find.byKey(const ValueKey('customer-seat-11')));
      await pumpRoute(tester);
      expect(tester.widget<FilledButton>(applySeats).onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('customer-seat-18')));
      await pumpRoute(tester);
      await tester.tap(find.byKey(const ValueKey('customer-seat-11')));
      await pumpRoute(tester);
      await tester.tap(applySeats);
      await pumpRoute(tester);
      expect(picker, findsNothing);
      expect(find.text('Confirm Booking'), findsOneWidget);
      expect(find.text('Ghế B4, B5, C6'), findsOneWidget);
      expect(bookings.createCalls, isEmpty);
      final confirm = find.byKey(const Key('confirmChatBooking'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await pumpRoute(tester);
      expect(
        bookings.createCalls.single.seatIds,
        unorderedEquals([10, 11, 18]),
      );
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

  testWidgets('Guest seat picker resumes after login finishes navigating', (
    tester,
  ) async {
    final session = SessionState();
    final service = ChatService(
      client: ApiClient(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': '[Chọn ghế](/showtimes/11/seats)'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      buildTestApp(session: session, chatService: service),
    );
    await pumpRoute(tester);
    await tester.tap(find.byKey(const Key('openCinemaChat')));
    await pumpRoute(tester);
    await tester.enterText(
      find.byKey(const Key('cinemaChatInput')),
      'Suất chiếu gần nhất',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('sendCinemaChat')));
    await pumpRoute(tester);
    expect(find.text('Đăng nhập để xem sơ đồ ghế'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('/showtimes/11/seats')));
    await pumpRoute(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await pumpRoute(tester);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    final picker = find.byKey(const Key('chatSeatPicker'));
    session.setAuthenticated(customerUser);
    await pumpRoute(tester);
    expect(picker, findsNothing);
    navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    await pumpRoute(tester);
    expect(picker, findsOneWidget);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final size in [const Size(375, 812), const Size(812, 375)]) {
      tester.view.physicalSize = size;
      await pumpRoute(tester);
      final close = tester.getRect(find.byTooltip('Đóng sơ đồ ghế'));
      final apply = tester.getRect(find.byKey(const Key('applyChatSeats')));
      expect(close.top, greaterThanOrEqualTo(16));
      expect(apply.bottom, lessThanOrEqualTo(size.height - 16));
      if (size.height > size.width) {
        expect(apply.bottom - close.top, lessThan(460));
        expect(close.top, greaterThan(100));
      }
      expect(tester.takeException(), isNull);
    }
  });

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
