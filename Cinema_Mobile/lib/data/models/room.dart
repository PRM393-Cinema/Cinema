import 'json_readers.dart';

class Room {
  const Room({required this.id, required this.name, required this.totalSeats});
  factory Room.fromJson(Map<String, Object?> json) => Room(
    id: readInt(json['id']),
    name: readString(json['name']),
    totalSeats: readInt(json['totalSeats']),
  );
  final int id;
  final String name;
  final int totalSeats;
}
