import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/data/models/app_notification.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/models/create_booking_request.dart';
import 'package:cinema_fe/data/models/movie.dart';
import 'package:cinema_fe/data/models/paged_result.dart';
import 'package:cinema_fe/data/models/payment.dart';
import 'package:cinema_fe/data/models/payos_checkout_request.dart';
import 'package:cinema_fe/data/models/seat.dart';
import 'package:cinema_fe/data/models/showtime.dart';
import 'package:cinema_fe/features/payment/payment_args.dart';
import 'package:flutter_test/flutter_test.dart';

// JSON shapes copied from the backend DTOs (ASP.NET camelCase output).
void main() {
  test('PagedResult maps MovieService movies', () {
    final result = PagedResult.fromJson({
      'items': [
        {
          'id': 7,
          'title': 'Inception',
          'description': 'Dream heist.',
          'durationMinutes': 148,
          'genre': 'Khoa học viễn tưởng, Hành động',
          'language': 'Tiếng Anh (Phụ đề Tiếng Việt)',
          'releaseDate': '2010-07-16',
          'posterUrl': 'https://image.tmdb.org/t/p/w500/poster.jpg',
          'trailerUrl': null,
          'status': 'ACTIVE',
          'createdAt': '2026-10-01T08:00:00',
        },
      ],
      'pageNumber': 1,
      'pageSize': 50,
      'totalPages': 1,
      'totalCount': 1,
      'hasPrevious': false,
      'hasNext': false,
    }, Movie.fromJson);

    final movie = result.items.single;
    expect(result.totalCount, 1);
    expect(movie.id, 7);
    expect(movie.title, 'Inception');
    expect(movie.durationText, '148 min');
    expect(movie.releaseYear, '2010');
    expect(movie.trailerUrl, isEmpty);
  });

  test('Movie without release date has no year', () {
    final movie = Movie.fromJson({
      'id': 1,
      'title': 'Untitled',
      'durationMinutes': 90,
      'releaseDate': '0001-01-01',
      'status': 'ACTIVE',
    });

    expect(movie.releaseDate, isNull);
    expect(movie.releaseYear, isEmpty);
  });

  test('Showtime and seats map MovieService responses', () {
    final showtime = Showtime.fromJson({
      'id': 11,
      'movieId': 7,
      'roomId': 2,
      'startTime': '2026-10-06T19:30:00',
      'endTime': '2026-10-06T21:58:00',
      'price': 90000.00,
      'status': 'OPEN',
    });

    expect(showtime.startTime, DateTime(2026, 10, 6, 19, 30));
    expect(showtime.price, 90000);
    expect(showtime.isOpen, isTrue);
    expect(showtime.roomLabel, 'Room 2');

    final seat = Seat.fromJson({
      'id': 21,
      'roomId': 2,
      'seatRow': 'C',
      'seatNumber': 5,
      'seatType': 'VIP',
    });
    expect(seat.label, 'C5');
    expect(seat.type, 'VIP');

    final data = ShowtimeSeatsData.fromOccupied(
      seats: [seat],
      occupiedSeatIds: const [21],
    );
    expect(data.statusOf(seat), SeatReservationStatus.booked);
  });

  test('Booking maps BookingService response', () {
    final booking = Booking.fromJson({
      'id': 101,
      'bookingCode': 'BK-20261005193000-123456',
      'userId': 3,
      'customerEmail': 'khachhang1@gmail.com',
      'showtimeId': 11,
      'status': 'PENDING',
      'totalAmount': 180000.00,
      'paymentId': null,
      'movieTitle': 'Inception',
      'showTime': '2026-10-06T19:30:00',
      'expiresAt': '2026-10-05T19:40:00',
      'createdAt': '2026-10-05T19:30:00.1234567',
      'seats': [
        {'id': 1, 'seatId': 5, 'seatLabel': 'B1', 'price': 90000.00},
        {'id': 2, 'seatId': 6, 'seatLabel': 'B2', 'price': 90000.00},
      ],
    });

    expect(booking.status, BookingStatus.pending);
    expect(booking.totalAmount, 180000);
    expect(booking.paymentId, isNull);
    expect(booking.seatLabels, 'B1, B2');
    expect(booking.isHoldExpired(DateTime(2026, 10, 5, 19, 35)), isFalse);
    expect(booking.isAwaitingPayment(DateTime(2026, 10, 5, 19, 41)), isFalse);
  });

  test('Booking cancellation follows the 2 hour refund policy', () {
    Booking confirmedAt(DateTime showTime) => Booking.fromJson({
      'id': 1,
      'bookingCode': 'BK-1',
      'userId': 3,
      'showtimeId': 11,
      'status': 'CONFIRMED',
      'totalAmount': 90000,
      'paymentId': 9,
      'showTime': showTime.toIso8601String(),
      'createdAt': '2026-10-05T10:00:00',
      'seats': const [],
    });

    final now = DateTime(2026, 10, 6, 17, 0);
    expect(confirmedAt(DateTime(2026, 10, 6, 19, 30)).canCancel(now), isTrue);
    expect(confirmedAt(DateTime(2026, 10, 6, 18, 30)).canCancel(now), isFalse);
  });

  test('Payment, checkout and refund map BookingService responses', () {
    final checkout = PayOsCheckout.fromJson({
      'paymentId': 501,
      'orderCode': 101,
      'checkoutUrl': 'https://pay.payos.vn/web/abc',
    });
    expect(checkout.orderCode, 101);
    expect(checkout.checkoutUrl, 'https://pay.payos.vn/web/abc');

    final payment = PaymentInfo.fromJson({
      'id': 501,
      'paymentCode': 'PAY-1',
      'bookingId': 101,
      'userId': 3,
      'recipientEmail': 'khachhang1@gmail.com',
      'amount': 180000,
      'method': 'PAYOS',
      'status': 'REFUND_PENDING',
      'transactionRef': '101',
      'createdAt': '2026-10-05T19:31:00',
      'updatedAt': null,
    });
    expect(payment.status, PaymentStatus.refundPending);

    final refund = Refund.fromJson({
      'id': 1,
      'refundCode': 'RF-1',
      'paymentId': 501,
      'bookingId': 101,
      'userId': 3,
      'amount': 180000,
      'reason': 'Customer cancelled',
      'status': 'COMPLETED',
      'transactionRef': 'FT123',
      'createdAt': '2026-10-05T20:00:00',
      'processedAt': '2026-10-05T21:00:00',
    });
    expect(refund.isCompleted, isTrue);
  });

  test('Requests serialize the fields the backend expects', () {
    expect(
      const CreateBookingRequest(showtimeId: 11, seatIds: [5, 6]).toJson(),
      {
        'showtimeId': 11,
        'seats': [
          {'seatId': 5},
          {'seatId': 6},
        ],
      },
    );

    expect(
      const PayOsCheckoutRequest(
        bookingId: 101,
        amount: 180000,
        returnUrl: 'http://localhost:8090/',
        cancelUrl: 'http://localhost:8090/',
      ).toJson(),
      {
        'bookingId': 101,
        'amount': 180000.0,
        'returnUrl': 'http://localhost:8090/',
        'cancelUrl': 'http://localhost:8090/',
      },
    );
  });

  test('PayOS return URL is parsed from the query string', () {
    final paid = PayOsReturn.fromUri(
      Uri.parse(
        'http://localhost:8090/?code=00&id=x&cancel=false&status=PAID&orderCode=101',
      ),
    );
    expect(paid?.orderCode, 101);
    expect(paid?.cancelled, isFalse);

    final cancelled = PayOsReturn.fromUri(
      Uri.parse(
        'http://localhost:8090/?cancel=true&status=CANCELLED&orderCode=7',
      ),
    );
    expect(cancelled?.cancelled, isTrue);

    expect(PayOsReturn.fromUri(Uri.parse('http://localhost:8090/')), isNull);
  });

  test('Notification HTML is shown as plain text', () {
    final notification = AppNotification.fromJson({
      'id': 1,
      'userId': 3,
      'bookingId': 101,
      'recipientEmail': 'khachhang1@gmail.com',
      'subject': 'Xác nhận đặt vé BK-1',
      'type': 'BOOKING_CONFIRMED',
      'content': '<h2>Đặt vé thành công</h2><ul><li>Phim: Chuy&#x1EBF;n t&#xE0;u</li></ul>',
      'status': 'SENT',
      'sentAt': '2026-10-05T19:31:00',
      'errorMessage': null,
      'createdAt': '2026-10-05T19:31:00',
    });

    expect(notification.plainContent, 'Đặt vé thành công\n• Phim: Chuyến tàu');
  });

  test('Showtime days are labelled today and tomorrow', () {
    final now = DateTime(2026, 10, 6, 15, 30);

    expect(
      formatDayHeading(DateTime(2026, 10, 6, 19), now: now),
      'Today · Tue, Oct 6',
    );
    expect(
      formatDayHeading(DateTime(2026, 10, 7, 13), now: now),
      'Tomorrow · Wed, Oct 7',
    );
    expect(formatDayHeading(DateTime(2026, 10, 9, 13), now: now), 'Fri, Oct 9');
  });

  test('Prices are formatted in Vietnamese dong', () {
    expect(formatVnd(90000), '90.000 ₫');
    expect(formatCountdown(const Duration(minutes: 9, seconds: 5)), '09:05');
    expect(formatCountdown(const Duration(seconds: -3)), '00:00');
  });
}
