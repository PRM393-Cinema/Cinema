import '../../core/network/api_client.dart';
import '../models/json_readers.dart';
import '../models/movie.dart';
import '../models/paged_result.dart';
import '../models/seat.dart';
import '../models/showtime.dart';

// Movies, showtimes and seat maps (MovieService behind the gateway).
class MovieService {
  MovieService({required ApiClient client}) : _apiClient = client;

  // MovieService caps page size at 50.
  static const maxPageSize = 50;

  final ApiClient _apiClient;

  Future<PagedResult<Movie>> getMoviesByStatus(
    String status, {
    int page = 1,
    int size = maxPageSize,
  }) async {
    final response = await _apiClient.get(
      '/api/v1/movies/status/${Uri.encodeComponent(status)}',
      query: {
        'page': page,
        'size': size,
        'sortBy': 'createdAt',
        'sortDir': 'desc',
      },
    );

    return PagedResult.fromJson(response, Movie.fromJson);
  }

  Future<Movie> getMovie(int movieId) async {
    final response = await _apiClient.get('/api/v1/movies/$movieId');
    return Movie.fromJson(readMap(response));
  }

  // Showtimes that are still open for booking and have not started yet.
  Future<PagedResult<Showtime>> getOpenShowtimesByMovie(
    int movieId, {
    int page = 1,
    int size = maxPageSize,
  }) async {
    final response = await _apiClient.get(
      '/api/showtimes/movie/$movieId/open',
      query: {
        'pageNumber': page,
        'pageSize': size,
        'sortBy': 'startTime',
        'sortDir': 'asc',
      },
    );

    return PagedResult.fromJson(response, Showtime.fromJson);
  }

  Future<List<Seat>> getSeatsByRoom(int roomId) async {
    final response = await _apiClient.get(
      '/api/seats/room/$roomId',
      authenticated: true,
    );

    return readMapList(response).map(Seat.fromJson).toList();
  }
}
