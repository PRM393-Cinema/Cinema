import 'json_readers.dart';

class Showtime {
  const Showtime({
    required this.id,
    required this.movieId,
    required this.roomId,
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.status,
    this.seatPrices = const {},
  });

  factory Showtime.fromJson(Map<String, Object?> json) {
    return Showtime(
      id: readInt(json['id']),
      movieId: readInt(json['movieId']),
      roomId: readInt(json['roomId']),
      startTime: readRequiredDateTime(json['startTime']),
      endTime: readRequiredDateTime(json['endTime']),
      price: readDouble(json['price']),
      status: readString(json['status'], fallback: 'OPEN'),
      seatPrices: {
        if (json['seatPrices'] case final Map prices)
          for (final MapEntry(:key, :value) in prices.entries)
            if (value is num) '$key'.toUpperCase(): value.toDouble(),
      },
    );
  }

  final int id;
  final int movieId;
  final int roomId;
  final DateTime startTime;
  final DateTime endTime;
  // The price of a standard seat.
  final double price;
  final String status; // 'OPEN', 'CLOSED', 'CANCELLED'

  // The price of one seat by type (NORMAL, VIP, SWEETBOX): VIP and sweetbox
  // seats cost more than [price].
  final Map<String, double> seatPrices;

  double priceOf(String seatType) =>
      seatPrices[seatType.toUpperCase()] ?? price;

  bool get isOpen => status == 'OPEN';

  // Room names are only exposed to staff, so customers see the room number.
  String get roomLabel => 'Room $roomId';
}
