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
    );
  }

  final int id;
  final int movieId;
  final int roomId;
  final DateTime startTime;
  final DateTime endTime;
  final double price;
  final String status; // 'OPEN', 'CLOSED', 'CANCELLED'

  bool get isOpen => status == 'OPEN';

  // Room names are only exposed to staff, so customers see the room number.
  String get roomLabel => 'Room $roomId';
}
