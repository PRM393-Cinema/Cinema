import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/models/showtime.dart';
import 'package:cinema_fe/features/booking/widgets/ticket_share_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  late FakeUrlLauncher urlLauncher;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    urlLauncher = FakeUrlLauncher();
    UrlLauncherPlatform.instance = urlLauncher;
  });

  final paid = bookingFixture(
    id: 501,
    status: BookingStatus.confirmed,
    paymentId: 9,
    showTime: DateTime(2030, 11, 6, 19, 30),
  );

  test('The shared text has the show, seats and ticket code', () {
    final text = ticketShareText(paid);
    expect(text, contains(inception.title));
    expect(text, contains('Seats B1, B2'));
    expect(text, contains('Ticket ${paid.bookingCode}'));
  });

  test('The calendar event covers the show in Vietnam time', () {
    final uri = calendarEventUri(
      paid,
      DateTime(2030, 11, 6, 19, 30),
      DateTime(2030, 11, 6, 22, 0),
    );
    expect(uri.host, 'calendar.google.com');
    expect(uri.queryParameters['dates'], '20301106T193000/20301106T220000');
    expect(uri.queryParameters['ctz'], 'Asia/Ho_Chi_Minh');
    expect(uri.queryParameters['text'], contains(inception.title));
  });

  testWidgets('A paid ticket is shared and added to the calendar', (
    tester,
  ) async {
    final shared = <String>[];
    final catalog = FakeCatalogRepository(
      showtimes: [
        Showtime(
          id: paid.showtimeId,
          movieId: inception.id,
          roomId: 1,
          startTime: paid.showTime!,
          endTime: DateTime(2030, 11, 6, 22, 0),
          price: 90000,
          status: 'OPEN',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketShareActions(
            booking: paid,
            catalogRepository: catalog,
            share: (text, subject) async => shared.add(text),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('shareTicket')));
    await tester.pump();
    expect(shared.single, ticketShareText(paid));

    await tester.tap(find.byKey(const Key('addToCalendar')));
    await tester.pump();
    final opened = Uri.parse(urlLauncher.launchedUrls.single);
    // The show's real end from the showtime.
    expect(opened.queryParameters['dates'], '20301106T193000/20301106T220000');
  });

  testWidgets('Without a share sheet the details are copied', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketShareActions(
            booking: paid,
            share: (text, subject) async => throw UnsupportedError('none'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('shareTicket')));
    await tester.pump();
    expect(copied, ticketShareText(paid));
    expect(find.textContaining('Ticket details copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('The ticket page offers sharing for a paid ticket', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        bookingRepository: FakeBookingRepository(bookings: [paid]),
        initialRoute: AppRoutes.bookingDetail(501),
      ),
    );
    await pumpRoute(tester);

    expect(find.byKey(const Key('shareTicket')), findsOneWidget);
    expect(find.byKey(const Key('addToCalendar')), findsOneWidget);
  });
}
