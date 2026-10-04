import 'seat.dart';
import 'showtime.dart';

class BookingDraft {
  const BookingDraft({
    required this.showtime,
    required this.seats,
  });

  final Showtime showtime;
  final List<Seat> seats;

  int get ticketCount => seats.length;
  double get totalPrice => ticketCount * showtime.price;
}
