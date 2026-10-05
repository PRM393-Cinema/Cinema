class Seat {
  const Seat({
    required this.id,
    required this.roomId,
    required this.row,
    required this.number,
    required this.type,
  });

  final String id;
  final String roomId;
  final String row;
  final int number;
  final String type;
}

enum SeatReservationStatus { available, held, booked }

// Cleanly separates static seat data from dynamic showtime state
class ShowtimeSeatsData {
  const ShowtimeSeatsData({
    required this.seats,
    required this.reservations,
  });

  final List<Seat> seats;
  final Map<String, SeatReservationStatus> reservations;
}
