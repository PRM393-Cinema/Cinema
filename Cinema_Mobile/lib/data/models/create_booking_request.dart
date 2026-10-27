class CreateBookingRequest {
  const CreateBookingRequest({
    required this.showtimeId,
    required this.seatIds,
    this.concessions = const {},
    this.promotionCode,
    this.usePoints = 0,
  });

  final int showtimeId;
  final List<int> seatIds;

  // Snack item id → quantity; the backend prices them from its menu.
  final Map<int, int> concessions;

  // A promo code typed in; without one the best automatic deal applies.
  final String? promotionCode;

  // Member points paying part of the price (1 point = 1,000 ₫).
  final int usePoints;

  // The backend reads the customer, movie title, show time and seat prices
  // itself, so only the showtime and seat ids are sent.
  Map<String, Object?> toJson() {
    return {
      'showtimeId': showtimeId,
      'seats': [
        for (final seatId in seatIds) {'seatId': seatId},
      ],
      'promotionCode': ?promotionCode,
      if (usePoints > 0) 'usePoints': usePoints,
      if (concessions.isNotEmpty)
        'concessions': [
          for (final MapEntry(key: itemId, value: quantity)
              in concessions.entries)
            if (quantity > 0) {'itemId': itemId, 'quantity': quantity},
        ],
    };
  }
}
