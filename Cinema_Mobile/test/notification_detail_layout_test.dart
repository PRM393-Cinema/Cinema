import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/data/models/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/test_app.dart';

final expiredNotification = AppNotification(
  id: 10,
  bookingId: 101,
  subject: 'Đơn đặt vé BK-2026-DOR002 đã hết hạn',
  type: 'BOOKING_EXPIRED',
  content: '''
    <h2>Đơn đặt vé đã hết hạn</h2>
    <p>Đơn đặt vé <strong>BK-2026-DOR002</strong> đã hết thời gian giữ ghế
      nên các ghế đã được nhả cho khách khác.</p>
    <p><strong>Phim:</strong> Doraemon: Đi Du Lịch Việt Nam<br/>
      <strong>Suất chiếu:</strong> 08/10/2026 00:55<br/>
      <strong>Ghế:</strong> A1<br/>
      <strong>Bắp nước:</strong> Combo bắp &amp; nước<br/>
      <strong>Tổng tiền:</strong> 110,000 VND</p>
    <p>Bạn có thể đặt lại vé nếu suất chiếu vẫn còn chỗ.</p>
    <p>Cảm ơn bạn đã sử dụng Mobile Cinema.</p>
  ''',
  status: 'SENT',
  createdAt: DateTime(2026, 10, 8, 19, 33),
);

void main() {
  for (final type in [
    'BOOKING_CONFIRMED',
    'BOOKING_CANCELLED',
    'BOOKING_EXPIRED',
    'SHOWTIME_REMINDER',
    'PAYMENT_REMINDER',
    'REFUND_REQUESTED',
    'REFUND_COMPLETED',
    'REFUND_REJECTED',
  ]) {
    testWidgets('$type uses the shared notification format', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final notification = AppNotification(
        id: 20,
        bookingId: 101,
        subject: 'Thông báo BK-TEST-001',
        type: type,
        status: 'SENT',
        createdAt: DateTime(2026),
        content:
            '<h2>Cập nhật vé</h2><p>Nội dung thông báo.</p>'
            '<p><strong>Số tiền hoàn:</strong> 110,000 VND<br/>'
            '<strong>Lý do:</strong> Khách yêu cầu<br/>'
            '<strong>Mã giao dịch chuyển khoản:</strong> REF-001</p>',
      );
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: FakeBookingRepository(
            notifications: [notification],
          ),
          initialRoute: AppRoutes.notifications,
        ),
      );
      await pumpRoute(tester);
      expect(find.text('Cập nhật vé'), findsOneWidget);
      expect(find.text('BK-TEST-001'), findsOneWidget);
      await tester.tap(find.text('Cập nhật vé'));
      await pumpRoute(tester);
      expect(find.text('Cập nhật vé'), findsOneWidget);
      expect(find.text('Số tiền hoàn'), findsOneWidget);
      expect(find.text('Lý do'), findsOneWidget);
      expect(find.text('Mã giao dịch chuyển khoản'), findsOneWidget);
      expect(find.text('110,000 VND'), findsOneWidget);
      expect(find.byKey(const Key('viewBooking')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final (size, scale) in [
    (const Size(375, 812), 1.0),
    (const Size(320, 812), 1.5),
    (const Size(375, 812), 3.2),
    (const Size(812, 375), 1.0),
  ]) {
    testWidgets('Notification groups ticket facts at $size, scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: FakeBookingRepository(
            notifications: [expiredNotification],
          ),
          initialRoute: AppRoutes.notificationDetail(10),
        ),
      );
      await pumpRoute(tester);

      expect(find.text('Đơn đặt vé đã hết hạn'), findsOneWidget);
      expect(find.text('BK-2026-DOR002'), findsOneWidget);
      expect(find.text('Phim'), findsOneWidget);
      expect(find.text('Doraemon: Đi Du Lịch Việt Nam'), findsOneWidget);
      expect(find.text('08/10/2026 00:55'), findsOneWidget);
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('Combo bắp & nước'), findsOneWidget);
      expect(find.text('110,000 VND'), findsOneWidget);
      expect(find.textContaining('giữ ghế nên các ghế'), findsOneWidget);
      expect(find.text('Cảm ơn bạn đã sử dụng Mobile Cinema.'), findsOneWidget);
      expect(find.byKey(const Key('writeReview')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('viewBooking')));
      await pumpRoute(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
