import '../models/showtime.dart';

final mockShowtimes = [
  Showtime(
    id: '101',
    movieId: '1',
    roomId: 'Room A',
    startTime: DateTime.now().add(const Duration(hours: 2)),
    endTime: DateTime.now().add(const Duration(hours: 4, minutes: 12)),
    price: 15.0,
    status: 'OPEN',
  ),
  Showtime(
    id: '102',
    movieId: '1',
    roomId: 'Room B',
    startTime: DateTime.now().add(const Duration(hours: 5)),
    endTime: DateTime.now().add(const Duration(hours: 7, minutes: 12)),
    price: 15.0,
    status: 'CLOSED',
  ),
  Showtime(
    id: '103',
    movieId: '1',
    roomId: 'VIP Lounge',
    startTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 4, minutes: 12)),
    price: 25.0,
    status: 'OPEN',
  ),
];
