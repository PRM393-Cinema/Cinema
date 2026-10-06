import 'json_readers.dart';

class Seat {
  const Seat({
    required this.id,
    required this.roomId,
    required this.row,
    required this.number,
    required this.type,
  });

  factory Seat.fromJson(Map<String, Object?> json) {
    return Seat(
      id: readInt(json['id']),
      roomId: readInt(json['roomId']),
      row: readString(json['seatRow']),
      number: readOptionalInt(json['seatNumber']) ?? 0,
      type: readString(json['seatType'], fallback: 'NORMAL'),
    );
  }

  final int id;
  final int roomId;
  final String row;
  final int number;
  final String type; // 'NORMAL', 'VIP'

  String get label => '$row$number';
}

enum SeatReservationStatus { available, held, booked }

// Cleanly separates static seat data from dynamic showtime state
class ShowtimeSeatsData {
  const ShowtimeSeatsData({required this.seats, required this.reservations});

  // The booking service reports held and booked seats together, so every
  // occupied seat is shown as booked.
  factory ShowtimeSeatsData.fromOccupied({
    required List<Seat> seats,
    required Iterable<int> occupiedSeatIds,
  }) {
    return ShowtimeSeatsData(
      seats: seats,
      reservations: {
        for (final seatId in occupiedSeatIds)
          seatId: SeatReservationStatus.booked,
      },
    );
  }

  final List<Seat> seats;
  final Map<int, SeatReservationStatus> reservations;

  SeatReservationStatus statusOf(Seat seat) {
    return reservations[seat.id] ?? SeatReservationStatus.available;
  }
}
