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

  // Every seat costs the showtime price; the backend recalculates the total.
  double get totalPrice => ticketCount * showtime.price;
}

// Arguments for the seat selection screen.
class SeatSelectionArgs {
  const SeatSelectionArgs({required this.movie, required this.showtime});

  final Movie movie;
  final Showtime showtime;
}
