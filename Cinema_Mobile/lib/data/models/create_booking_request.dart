class CreateBookingRequest {
  const CreateBookingRequest({
    required this.showtimeId,
    required this.seatIds,
    this.concessions = const {},
  });

  final int showtimeId;
  final List<int> seatIds;

  // Snack item id → quantity; the backend prices them from its menu.
  final Map<int, int> concessions;

  // The backend reads the customer, movie title, show time and seat prices
  // itself, so only the showtime and seat ids are sent.
  Map<String, Object?> toJson() {
    return {
      'showtimeId': showtimeId,
      'seats': [
        for (final seatId in seatIds) {'seatId': seatId},
      ],
      if (concessions.isNotEmpty)
        'concessions': [
          for (final MapEntry(key: itemId, value: quantity)
              in concessions.entries)
            if (quantity > 0) {'itemId': itemId, 'quantity': quantity},
        ],
    };
  }
}
