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
  refundPending,
  cancelled,
  expired;

  static BookingStatus parse(String value) {
    if (value.toUpperCase() == 'REFUND_PENDING') {
      return BookingStatus.refundPending;
    }
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
    this.checkedInAt,
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
      checkedInAt: readDateTime(json['checkedInAt']),
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

  // When the customer checked in at the cinema (staff scanned the ticket).
  final DateTime? checkedInAt;
  final DateTime createdAt;
  final List<BookingSeat> seats;

  bool get isCheckedIn => checkedInAt != null;

  // A paid ticket that has not been used yet: its QR code gets the customer
  // in. The server also checks the time of the show.
  bool get canCheckIn => status == BookingStatus.confirmed && !isCheckedIn;

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

// A seat of a showtime that a booking holds or has sold, for the staff seat
// map of the showtime.
class ShowtimeSeatBooking {
  const ShowtimeSeatBooking({
    required this.seatId,
    required this.seatLabel,
    required this.bookingId,
    required this.bookingCode,
    required this.status,
    this.checkedInAt,
  });

  factory ShowtimeSeatBooking.fromJson(Map<String, Object?> json) {
    return ShowtimeSeatBooking(
      seatId: readInt(json['seatId']),
      seatLabel: readString(json['seatLabel']),
      bookingId: readInt(json['bookingId']),
      bookingCode: readString(json['bookingCode']),
      status: BookingStatus.parse(readString(json['status'])),
      checkedInAt: readDateTime(json['checkedInAt']),
    );
  }

  final int seatId;
  final String seatLabel;
  final int bookingId;
  final String bookingCode;
  final BookingStatus status;
  final DateTime? checkedInAt;
}
