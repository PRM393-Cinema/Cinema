import 'json_readers.dart';

class BookingSeat {
  const BookingSeat({
    required this.id,
    required this.seatId,
    required this.seatLabel,
    required this.price,
  });

  factory BookingSeat.fromJson(Map<String, Object?> json) {
    return BookingSeat(
      id: readInt(json['id']),
      seatId: readInt(json['seatId']),
      seatLabel: readString(json['seatLabel']),
      price: readDouble(json['price']),
    );
  }

  final int id;
  final int seatId;
  final String seatLabel;
  final double price;
}

enum BookingStatus {
  pending,
  confirmed,
  cancelled,
  expired;

  static BookingStatus parse(String value) {
    return BookingStatus.values.firstWhere(
      (status) => status.name == value.toLowerCase(),
      orElse: () => BookingStatus.pending,
    );
  }
}

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

  factory Booking.fromJson(Map<String, Object?> json) {
    return Booking(
      id: readInt(json['id']),
      bookingCode: readString(json['bookingCode']),
      userId: readInt(json['userId']),
      customerEmail: readOptionalString(json['customerEmail']),
      showtimeId: readInt(json['showtimeId']),
      status: BookingStatus.parse(readString(json['status'])),
      totalAmount: readDouble(json['totalAmount']),
      paymentId: readOptionalInt(json['paymentId']),
      movieTitle: readOptionalString(json['movieTitle']),
      showTime: readDateTime(json['showTime']),
      expiresAt: readDateTime(json['expiresAt']),
      createdAt: readRequiredDateTime(json['createdAt']),
      seats: readMapList(json['seats']).map(BookingSeat.fromJson).toList(),
    );
  }

  // Customers can cancel a paid booking for a full refund until this long
  // before the show (backend RefundPolicy:CustomerCancelBeforeHours).
  static const cancelBeforeShowtime = Duration(hours: 2);

  final int id;
  final String bookingCode;
  final int userId;
  final String? customerEmail;
  final int showtimeId;
  final BookingStatus status;
  final double totalAmount;
  final int? paymentId;
  final String? movieTitle;
  final DateTime? showTime;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final List<BookingSeat> seats;

  String get seatLabels => seats.map((seat) => seat.seatLabel).join(', ');

  bool isHoldExpired([DateTime? now]) {
    return expiresAt != null && !expiresAt!.isAfter(now ?? DateTime.now());
  }

  bool isAwaitingPayment([DateTime? now]) {
    return status == BookingStatus.pending && !isHoldExpired(now);
  }

  bool canCancel([DateTime? now]) {
    if (status == BookingStatus.pending) {
      return true;
    }
    if (status != BookingStatus.confirmed || showTime == null) {
      return false;
    }
    return showTime!.difference(now ?? DateTime.now()) >= cancelBeforeShowtime;
  }
}
