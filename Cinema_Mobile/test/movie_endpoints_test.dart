import 'dart:async';
import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/widgets/cinema_account_widgets.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/repositories/catalog_repository.dart';
import 'package:cinema_fe/data/services/booking_service.dart';
import 'package:cinema_fe/data/services/movie_service.dart';
import 'package:cinema_fe/data/storage/auth_token_storage.dart';
import 'package:cinema_fe/data/storage/token_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fixtures.dart';
import 'support/fakes.dart';
import 'support/test_app.dart';

final _admin = AuthUser.fromJson({
  ...customerUser.toJson(),
  'roles': ['ROLE_ADMIN'],
});
Map<String, Object?> _movie(String title, {String status = 'ACTIVE'}) => {
  'id': 7,
  'title': title,
  'description': 'A movie',
  'durationMinutes': 120,
  'genre': 'Drama',
  'language': 'Vietnamese',
  'releaseDate': '2026-10-11',
  'posterUrl': '',
  'trailerUrl': '',
  'status': status,
};
http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Map<String, Object?> _page(
  List<Map<String, Object?>> items, {
  int page = 1,
  int pages = 1,
}) => {
  'items': items,
  'pageNumber': page,
  'totalPages': pages,
  'totalCount': items.length,
};

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'Admin Movies tab and Profile select correctly with four destinations',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = MovieService(
        client: ApiClient(
          httpClient: MockClient((_) async => _json(_page([]))),
        ),
      );
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          user: _admin,
          authRepository: FakeAuthRepository(user: _admin),
          movieService: service,
          initialRoute: AppRoutes.adminMovies,
        ),
      );
      await pumpRoute(tester);
      var nav = tester.widget<CinemaNavigationBar>(
        find.byType(CinemaNavigationBar),
      );
      expect(nav.destinations.map((destination) => destination.$1), [
        'Dashboard',
        'Accounts',
        'Movies',
        'Profile',
      ]);
      expect(nav.selectedIndex, 2);
      await tester.tap(find.text('Profile'));
      await pumpRoute(tester);
      nav = tester.widget<CinemaNavigationBar>(
        find.byType(CinemaNavigationBar),
      );
      expect(nav.selectedIndex, 3);
      await tester.tap(find.text('Movies'));
      await pumpRoute(tester);
      expect(find.text('Create movie'), findsOneWidget);
      await tester.tap(find.text('Dashboard'));
      await pumpRoute(tester);
      expect(find.text('Manage movies'), findsNothing);
      expect(find.text('Movies'), findsOneWidget);
      await tester.tap(find.text('Profile'));
      await pumpRoute(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(buildTestApp());
      await pumpRoute(tester);
      nav = tester.widget<CinemaNavigationBar>(
        find.byType(CinemaNavigationBar),
      );
      expect(nav.destinations.length, 3);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Search passes keyword/pages and excludes inactive movies across pages',
    () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          final page = int.parse(request.url.queryParameters['page']!);
          return _json(
            _page(
              page == 1
                  ? [_movie('Phim mới'), _movie('Inactive', status: 'INACTIVE')]
                  : [_movie('Phim mới 2')],
              page: page,
              pages: 2,
            ),
          );
        }),
      );
      final catalog = RemoteCatalogRepository(
        movieService: MovieService(client: client),
        bookingService: BookingService(client: client),
      );
      expect(
        (await catalog.searchMovies(' Phim mới ')).map((movie) => movie.title),
        ['Phim mới', 'Phim mới 2'],
      );
      expect(requests.map((request) => request.url.path), [
        '/api/v1/movies/search',
        '/api/v1/movies/search',
      ]);
      expect(requests.first.url.queryParameters['keyword'], 'Phim mới');
      expect(requests.last.url.queryParameters['page'], '2');
    },
  );

  testWidgets('Admin creates, edits and confirms deletion through movie APIs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 924);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = SecureAuthTokenStorage();
    await storage.save(authResponseFixture);
    final manager = TokenManager(
      storage: storage,
      refreshSession: (_) async => throw StateError('Must not refresh'),
    );
    final writes = <http.Request>[];
    var items = <Map<String, Object?>>[];
    final client = ApiClient(
      tokenProvider: manager,
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/auth/me') {
          return _json(_admin.toJson());
        }
        if (request.method == 'GET') {
          return _json(
            request.url.path.endsWith('/7') ? items.single : _page(items),
          );
        }
        writes.add(request);
        if (request.method == 'DELETE') {
          items = [
            {...items.single, 'status': 'INACTIVE'},
          ];
          return http.Response('', 204);
        }
        if (request.method == 'PATCH') {
          items = [
            {...items.single, 'status': 'ACTIVE'},
          ];
          return _json(items.single);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        items = [
          {..._movie(body['title'] as String), ...body},
        ];
        return _json(
          items.single,
          status: request.method == 'POST' ? 201 : 200,
        );
      }),
    );
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        user: _admin,
        movieService: MovieService(client: client),
        initialRoute: AppRoutes.adminMovies,
      ),
    );
    await pumpRoute(tester);
    await tester.tap(find.text('Create movie'));
    await pumpRoute(tester);
    await _tapSave(tester);
    expect(writes, isEmpty);
    await tester.ensureVisible(find.byKey(const Key('movie_title')));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('movie_title')),
        matching: find.byType(TextFormField),
      ),
      'Phim mới',
    );
    await _tapSave(tester);
    await pumpRoute(tester);
    expect(writes.single.method, 'POST');
    expect(writes.single.url.path, '/api/v1/movies');
    expect(writes.single.headers['Authorization'], 'Bearer access-token');
    expect((jsonDecode(writes.single.body) as Map)['durationMinutes'], 60);
    expect(find.text('Movie created.'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit Phim mới'));
    await pumpRoute(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('movie_title')),
        matching: find.byType(TextFormField),
      ),
      'Updated movie',
    );
    await _tapSave(tester);
    await pumpRoute(tester);
    expect(writes.last.method, 'PUT');
    expect(writes.last.url.path, '/api/v1/movies/7');
    expect(find.text('Movie updated.'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete Updated movie'));
    await pumpRoute(tester);
    await tester.tap(find.text('Cancel'));
    await pumpRoute(tester);
    expect(writes.length, 2);
    await tester.tap(find.byTooltip('Delete Updated movie'));
    await pumpRoute(tester);
    await tester.tap(find.text('Delete').last);
    await pumpRoute(tester);
    expect(writes.last.method, 'DELETE');
    expect(writes.last.url.path, '/api/v1/movies/7');
    expect(find.text('Movie deactivated.'), findsOneWidget);
    expect(find.text('Updated movie'), findsOneWidget);
    expect(find.text('60 min · INACTIVE'), findsOneWidget);
    await tester.tap(find.byTooltip('Activate Updated movie'));
    await pumpRoute(tester);
    expect(writes.last.method, 'PATCH');
    expect(writes.last.url.path, '/api/v1/movies/7/activate');
    expect(writes.last.headers['Authorization'], 'Bearer access-token');
    expect(find.text('Movie activated.'), findsOneWidget);
    expect(find.text('Updated movie'), findsOneWidget);
    expect(find.text('60 min · ACTIVE'), findsOneWidget);
    expect(find.byTooltip('Delete Updated movie'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home searches the API and ignores responses to older keywords', (
    tester,
  ) async {
    final oldSearch = Completer<http.Response>();
    final keywords = <String>[];
    final client = ApiClient(
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/search')) {
          final keyword = request.url.queryParameters['keyword']!;
          keywords.add(keyword);
          if (keyword == 'Old') return oldSearch.future;
          return _json(_page([_movie('Phim mới')]));
        }
        return _json(_page([_movie('Initial movie')]));
      }),
    );
    await tester.pumpWidget(
      buildTestApp(
        catalogRepository: RemoteCatalogRepository(
          movieService: MovieService(client: client),
          bookingService: BookingService(client: client),
        ),
      ),
    );
    await pumpRoute(tester);
    final input = find.descendant(
      of: find.byKey(const Key('movieSearchField')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(input, 'Old');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(input, 'Phim mới');
    await tester.pump(const Duration(milliseconds: 400));
    await pumpRoute(tester);
    oldSearch.complete(_json(_page([_movie('Old result')])));
    await pumpRoute(tester);
    expect(keywords, ['Old', 'Phim mới']);
    expect(find.text('Phim mới'), findsWidgets);
    expect(find.text('Old result'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final role in ['ROLE_CUSTOMER', 'ROLE_STAFF']) {
    testWidgets('$role cannot open movie management', (tester) async {
      var requests = 0;
      final service = MovieService(
        client: ApiClient(
          httpClient: MockClient((_) async {
            requests++;
            return _json(_page([]));
          }),
        ),
      );
      final user = AuthUser.fromJson({
        ...customerUser.toJson(),
        'roles': [role],
      });
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          user: user,
          movieService: service,
          initialRoute: AppRoutes.adminCreateMovie,
        ),
      );
      await pumpRoute(tester);
      expect(find.text('Save movie'), findsNothing);
      expect(requests, 0);
    });
  }
}

Future<void> _tapSave(WidgetTester tester) async {
  final scrollable = find
      .descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    find.text('Save movie'),
    200,
    scrollable: scrollable,
  );
  await tester.drag(find.byType(ListView).first, const Offset(0, -140));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save movie'));
  await tester.pump();
}
