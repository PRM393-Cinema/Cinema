import 'dart:convert';

import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/data/repositories/booking_repository.dart';
import 'package:cinema_fe/data/repositories/catalog_repository.dart';
import 'package:cinema_fe/data/services/booking_service.dart';
import 'package:cinema_fe/data/services/movie_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final movies in [true, false]) {
    test(
      'Customer ${movies ? 'movies' : 'bookings'} includes every API page',
      () async {
        final pages = <int>[];
        final client = ApiClient(
          httpClient: MockClient((request) async {
            final page = int.parse(request.url.queryParameters['page']!);
            pages.add(page);
            expect(
              request.url.path,
              movies ? '/api/v1/movies/browse' : '/api/v1/bookings/user/3',
            );
            if (movies) {
              expect(request.url.queryParameters['when'], 'soon');
              expect(request.url.queryParameters['genre'], 'Drama');
              expect(request.url.queryParameters['keyword'], 'Film');
            }
            return http.Response(
              jsonEncode({
                'items': [
                  movies
                      ? {'id': page, 'title': 'Film $page'}
                      : {
                          'id': page,
                          'bookingCode': 'BK-$page',
                          'showtimeId': 11,
                          'status': 'CONFIRMED',
                          'totalAmount': 90000,
                          'createdAt': '2026-11-01T10:00:00',
                          'seats': [],
                        },
                ],
                'pageNumber': page,
                'totalPages': 3,
                'totalCount': 3,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        final service = BookingService(client: client);
        final ids = movies
            ? (await RemoteCatalogRepository(
                    movieService: MovieService(client: client),
                    bookingService: service,
                  ).browseMovies(
                    comingSoon: true,
                    genre: 'Drama',
                    keyword: 'Film',
                  ))
                  .map((movie) => movie.id)
            : (await RemoteBookingRepository(service: service).getMyBookings(3))
                  .map((booking) => booking.id);
        expect(ids, [1, 2, 3]);
        expect(pages, [1, 2, 3]);
      },
    );
  }
}
