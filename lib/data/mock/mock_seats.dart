import '../models/seat.dart';

final List<Seat> mockSeats = _generateMockSeats();

List<Seat> _generateMockSeats() {
  final seats = <Seat>[];
  final rows = ['A', 'B', 'C', 'D', 'E', 'F'];
  final seatsPerRow = [6, 8, 8, 8, 10, 10]; // staggered rows

  int idCounter = 1;
  for (int i = 0; i < rows.length; i++) {
    final row = rows[i];
    final count = seatsPerRow[i];
    for (int j = 1; j <= count; j++) {
      seats.add(Seat(
        id: idCounter.toString(),
        roomId: 'Room A',
        row: row,
        number: j,
        type: i >= 4 ? 'VIP' : 'NORMAL', // Last two rows are VIP
      ));
      idCounter++;
    }
  }
  return seats;
}

final ShowtimeSeatsData mockShowtimeSeatsData = ShowtimeSeatsData(
  seats: mockSeats,
  reservations: {
    '2': SeatReservationStatus.booked,
    '3': SeatReservationStatus.booked,
    '15': SeatReservationStatus.held,
    '16': SeatReservationStatus.held,
    '22': SeatReservationStatus.booked,
    '23': SeatReservationStatus.booked,
    '40': SeatReservationStatus.booked,
  },
);
