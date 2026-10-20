import 'movie.dart';
import 'seat.dart';
import 'showtime.dart';

class BookingDraft {
  const BookingDraft({
    required this.movie,
    required this.showtime,
    required this.seats,
  });

  final Movie movie;
  final Showtime showtime;
  final List<Seat> seats;

  int get ticketCount => seats.length;

  // Each seat costs the showtime price of its type; the backend recalculates
  // the total.
  double get totalPrice =>
      seats.fold(0, (total, seat) => total + showtime.priceOf(seat.type));
}

// Arguments for the seat selection screen.
class SeatSelectionArgs {
  const SeatSelectionArgs({required this.movie, required this.showtime});

  final Movie movie;
  final Showtime showtime;
}
