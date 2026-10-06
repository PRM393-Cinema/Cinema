class CreateBookingRequest {
  const CreateBookingRequest({required this.showtimeId, required this.seatIds});

  final int showtimeId;
  final List<int> seatIds;

  // The backend reads the customer, movie title, show time and seat prices
  // itself, so only the showtime and seat ids are sent.
  Map<String, Object?> toJson() {
    return {
      'showtimeId': showtimeId,
      'seats': [
        for (final seatId in seatIds) {'seatId': seatId},
      ],
    };
  }
}
