import 'package:cinema_fe/data/models/app_notification.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/models/movie.dart';
import 'package:cinema_fe/data/models/otp_sent_response.dart';
import 'package:cinema_fe/data/models/payment.dart';
import 'package:cinema_fe/data/models/seat.dart';
import 'package:cinema_fe/data/models/showtime.dart';

final customerUser = AuthUser(
  userId: 3,
  email: 'khachhang1@gmail.com',
  fullName: 'Nguyen Van Khach',
  phone: '0901234567',
  enabled: true,
  emailVerified: true,
  createdAt: DateTime(2026, 9, 1),
  roles: const ['ROLE_CUSTOMER'],
);

final authResponseFixture = AuthResponse(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  tokenType: 'Bearer',
  expiresAt: DateTime(2026, 10, 4, 12),
  user: customerUser,
);

const otpResponseFixture = OtpSentResponse(
  email: 'jane@example.com',
  message: 'OTP sent.',
  expiresInSeconds: 300,
  resendAfterSeconds: 0,
);

const inception = Movie(
  id: 1,
  title: 'Inception',
  description: 'A thief who steals secrets through dream-sharing.',
  durationMinutes: 148,
  genre: 'Sci-Fi, Action',
  language: 'English (Vietnamese subtitles)',
  releaseDate: null,
  posterUrl: '',
  trailerUrl: '',
  status: 'ACTIVE',
);

final movieFixtures = [
  inception,
  Movie(
    id: 2,
    title: 'Interstellar',
    description: 'Explorers travel through a wormhole in space.',
    durationMinutes: 169,
    genre: 'Sci-Fi, Adventure',
    language: 'English',
    releaseDate: DateTime(2014, 11, 7),
    posterUrl: '',
    trailerUrl: '',
    status: 'ACTIVE',
  ),
  Movie(
    id: 3,
    title: 'Oppenheimer',
    description: 'The story of J. Robert Oppenheimer.',
    durationMinutes: 180,
    genre: 'Biography, Drama',
    language: 'English',
    releaseDate: DateTime(2023, 7, 21),
    posterUrl: '',
    trailerUrl: '',
    status: 'ACTIVE',
  ),
];

// Tomorrow at 19:30, so the showtime is always in the future.
DateTime tomorrowEvening() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1, 19, 30);
}

Showtime showtimeFixture({int id = 11, double price = 90000}) {
  final start = tomorrowEvening();
  return Showtime(
    id: id,
    movieId: inception.id,
    roomId: 1,
    startTime: start,
    endTime: start.add(const Duration(minutes: 148)),
    price: price,
    status: 'OPEN',
  );
}

// Room 1: rows A and B with 4 seats each; A2 is already taken.
final seatMapFixture = ShowtimeSeatsData.fromOccupied(
  seats: [
    for (final (index, row) in ['A', 'B'].indexed)
      for (var number = 1; number <= 4; number++)
        Seat(
          id: index * 4 + number,
          roomId: 1,
          row: row,
          number: number,
          type: 'NORMAL',
        ),
  ],
  occupiedSeatIds: const [2],
);

Booking bookingFixture({
  int id = 101,
  String code = 'BK-20261005193000-111111',
  BookingStatus status = BookingStatus.pending,
  int? paymentId,
  DateTime? showTime,
  DateTime? expiresAt,
  List<String> seatLabels = const ['B1', 'B2'],
}) {
  return Booking(
    id: id,
    bookingCode: code,
    userId: customerUser.userId,
    customerEmail: customerUser.email,
    showtimeId: 11,
    status: status,
    totalAmount: 90000.0 * seatLabels.length,
    paymentId: paymentId,
    movieTitle: inception.title,
    showTime: showTime ?? tomorrowEvening(),
    expiresAt:
        expiresAt ??
        (status == BookingStatus.pending
            ? DateTime.now().add(const Duration(minutes: 10))
            : null),
    createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
    seats: [
      for (final (index, label) in seatLabels.indexed)
        BookingSeat(
          id: id * 10 + index,
          seatId: index + 5,
          seatLabel: label,
          price: 90000,
        ),
    ],
  );
}

PaymentInfo paymentFixture({
  int bookingId = 101,
  PaymentStatus status = PaymentStatus.success,
}) {
  return PaymentInfo(
    id: 501,
    paymentCode: 'PAY-501',
    bookingId: bookingId,
    amount: 180000,
    status: status,
    method: 'PAYOS',
    transactionRef: '$bookingId',
    createdAt: DateTime.now(),
  );
}

final notificationFixture = AppNotification(
  id: 1,
  bookingId: 101,
  subject: 'Xác nhận đặt vé BK-20261005193000-111111',
  type: 'BOOKING_CONFIRMED',
  content:
      '<h2>Đặt vé thành công</h2><p>Đơn đặt vé <strong>BK-1</strong> đã được xác nhận.</p>'
      '<p>Phim: Inception &amp; b&#x1EA1;n</p>',
  status: 'SENT',
  sentAt: DateTime(2026, 10, 5, 19, 0),
  createdAt: DateTime(2026, 10, 5, 19, 0),
);
