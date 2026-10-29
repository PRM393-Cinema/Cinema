import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/core/session/session_state.dart';
import 'package:cinema_fe/data/models/movie.dart';
import 'package:cinema_fe/features/movie/screens/movie_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/test_app.dart';

const _movie = Movie(
  id: 6,
  title: 'Doraemon: Đi Du Lịch Việt Nam',
  description:
      'Doraemon và những người bạn khám phá danh lam thắng cảnh Việt Nam.',
  durationMinutes: 108,
  genre: 'Hoạt hình, Phiêu lưu, Gia đình',
  language: 'Tiếng Nhật (Phụ đề & Lồng tiếng Việt)',
  releaseDate: null,
  posterUrl: '',
  trailerUrl: '',
  status: 'ACTIVE',
);

void main() {
  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(1024, 768),
  ]) {
    for (final scale in [1.0, 3.2]) {
      testWidgets('Movie overview reflows at $size with text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await tester.pumpWidget(
          SessionProvider(
            sessionState: SessionState()..setGuest(),
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: MovieDetailScreen(
                catalogRepository: FakeCatalogRepository(
                  movies: [_movie],
                  showtimes: const [],
                ),
                bookingRepository: FakeBookingRepository(),
                movieId: _movie.id,
              ),
            ),
          ),
        );
        await pumpRoute(tester);
        final poster = tester.getRect(
          find.byKey(const Key('movieOverviewPoster')),
        );
        final title = tester.getRect(
          find.byKey(const Key('movieOverviewTitle')),
        );
        final genre = tester.getRect(find.text(_movie.genre));
        if (size.width < 760) {
          expect(poster.width, greaterThan(250));
          expect(genre.top, greaterThanOrEqualTo(poster.bottom));
          expect(genre.left, title.left);
          expect(title.top, greaterThan(poster.bottom));
        }
        expect(title.right, lessThanOrEqualTo(size.width));
      });
    }
  }
}
