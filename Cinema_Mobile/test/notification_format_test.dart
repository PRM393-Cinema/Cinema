import 'package:cinema_fe/data/models/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification notice(String content) => AppNotification(
  id: 1,
  subject: 'Thông báo đơn BK-2026-TEST001',
  type: 'BOOKING_CONFIRMED',
  content: content,
  status: 'SENT',
  createdAt: DateTime(2026, 10, 29),
);

void main() {
  test(
    'List and detail use the same heading and body without repeating it',
    () {
      final n = notice(
        '<h2>Đặt vé <b>thành công</b></h2><p>Phim: A &amp; B</p>',
      );
      expect(n.displayTitle, 'Đặt vé thành công');
      expect(n.bookingCode, 'BK-2026-TEST001');
      expect(n.previewText, 'Phim: A & B');
      expect(n.bodyContent, '<p>Phim: A &amp; B</p>');
    },
  );
  test('Old plain notifications keep their content and subject', () {
    final n = notice('Nhắc thanh toán vé\nGhế: A1');
    expect(n.displayTitle, n.subject);
    expect(n.bodyContent, 'Nhắc thanh toán vé\nGhế: A1');
    expect(n.previewText, 'Nhắc thanh toán vé Ghế: A1');
  });
  test(
    'Headings with attributes and booking codes in the body are supported',
    () {
      final n = AppNotification(
        id: 2,
        subject: 'Hoàn tiền',
        type: 'REFUND_COMPLETED',
        content: '<H3 class="title"> Đã hoàn tiền </H3><p>Đơn BK-TEST-002</p>',
        status: 'SENT',
        createdAt: DateTime(2026),
      );
      expect(n.displayTitle, 'Đã hoàn tiền');
      expect(n.bookingCode, 'BK-TEST-002');
      expect(n.previewText, 'Đơn BK-TEST-002');
    },
  );
}
