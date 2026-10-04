class BookingSeat {
  const BookingSeat({
    required this.id,
    required this.seatId,
    required this.seatLabel,
    required this.price,
  });

  final String id;
  final String seatId;
  final String seatLabel;
  final double price;
}

enum BookingStatus { pending, confirmed, cancelled, expired }

class Booking {
  const Booking({
    required this.id,
    required this.bookingCode,
    required this.userId,
    this.customerEmail,
    required this.showtimeId,
    required this.status,
    required this.totalAmount,
    this.paymentId,
    this.movieTitle,
    this.showTime,
    this.expiresAt,
    required this.createdAt,
    required this.seats,
  });

  final String id;
  final String bookingCode;
  final String userId;
  final String? customerEmail;
  final String showtimeId;
  final BookingStatus status;
  final double totalAmount;
  final String? paymentId;
  final String? movieTitle;
  final DateTime? showTime;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final List<BookingSeat> seats;
}
