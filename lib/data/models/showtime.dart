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

  final String id;
  final String movieId;
  final String roomId;
  final DateTime startTime;
  final DateTime endTime;
  final double price;
  final String status; // 'OPEN', 'CLOSED', 'CANCELLED'

  bool get isOpen => status == 'OPEN';
}
