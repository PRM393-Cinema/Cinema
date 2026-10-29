import '../models/movie.dart';
import '../models/seat.dart';
import '../models/showtime.dart';
import '../services/booking_service.dart';
import '../services/movie_service.dart';
import '../models/review.dart';

abstract interface class CatalogRepository {
  Future<List<Movie>> getNowShowingMovies();

  // Home: movies now showing (or coming soon), filtered by genre and title.
  Future<List<Movie>> browseMovies({
    bool comingSoon = false,
    String? genre,
    String? keyword,
  });

  Future<List<String>> getGenres();

  // Ratings of a movie by customers who watched it.
  Future<MovieReviews> getMovieReviews(int movieId);

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
  Future<List<Movie>> browseMovies({
    bool comingSoon = false,
    String? genre,
    String? keyword,
  }) async {
    final result = await _movies.browseMovies(
      comingSoon: comingSoon,
      genre: genre,
      keyword: keyword,
    );
    return result.items;
  }

  @override
  Future<List<String>> getGenres() => _movies.getGenres();

  @override
  Future<MovieReviews> getMovieReviews(int movieId) =>
      _bookings.getMovieReviews(movieId);

  @override
  Future<Movie> getMovie(int movieId) => _movies.getMovie(movieId);

  @override
  Future<Showtime> getShowtime(int showtimeId) =>
      _movies.getShowtime(showtimeId);

  // Customers choose from the coming week. The schedule runs a month ahead,
  // so only the pages that still reach into that week are fetched (the API
  // sorts by start time).
  static const showtimeWindow = Duration(days: 7);

  @override
  Future<List<Showtime>> getOpenShowtimes(int movieId) async {
    final until = DateTime.now().add(showtimeWindow);
    var result = await _movies.getOpenShowtimesByMovie(movieId);
    final showtimes = [...result.items];
    for (
      var page = 2;
      page <= result.totalPages &&
          showtimes.isNotEmpty &&
          showtimes.last.startTime.isBefore(until);
      page++
    ) {
      result = await _movies.getOpenShowtimesByMovie(movieId, page: page);
      showtimes.addAll(result.items);
    }
    return showtimes.where((s) => s.startTime.isBefore(until)).toList();
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
