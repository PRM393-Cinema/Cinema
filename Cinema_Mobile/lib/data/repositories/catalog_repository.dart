import '../models/movie.dart';
import '../models/seat.dart';
import '../models/showtime.dart';
import '../services/booking_service.dart';
import '../services/movie_service.dart';

abstract interface class CatalogRepository {
  Future<List<Movie>> getNowShowingMovies();

  // Used when a screen is opened from its URL (web refresh or shared link).
  Future<Movie> getMovie(int movieId);

  Future<Showtime> getShowtime(int showtimeId);

  Future<List<Showtime>> getOpenShowtimes(int movieId);

  // Seat map of the showtime's room with the seats already held or booked.
  Future<ShowtimeSeatsData> getSeatMap(Showtime showtime);
}

class RemoteCatalogRepository implements CatalogRepository {
  RemoteCatalogRepository({
    required MovieService movieService,
    required BookingService bookingService,
  }) : _movies = movieService,
       _bookings = bookingService;

  final MovieService _movies;
  final BookingService _bookings;

  @override
  Future<List<Movie>> getNowShowingMovies() async {
    final result = await _movies.getMoviesByStatus('ACTIVE');
    return result.items;
  }

  @override
  Future<Movie> getMovie(int movieId) => _movies.getMovie(movieId);

  @override
  Future<Showtime> getShowtime(int showtimeId) =>
      _movies.getShowtime(showtimeId);

  @override
  Future<List<Showtime>> getOpenShowtimes(int movieId) async {
    final result = await _movies.getOpenShowtimesByMovie(movieId);
    return result.items;
  }

  @override
  Future<ShowtimeSeatsData> getSeatMap(Showtime showtime) async {
    final results = await Future.wait([
      _movies.getSeatsByRoom(showtime.roomId),
      _bookings.getOccupiedSeatIds(showtime.id),
    ]);

    return ShowtimeSeatsData.fromOccupied(
      seats: results[0] as List<Seat>,
      occupiedSeatIds: results[1] as List<int>,
    );
  }
}
