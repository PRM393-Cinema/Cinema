import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/mock/mock_movies.dart';
import '../../../data/models/movie.dart';
import '../../movie/widgets/movie_card.dart';
import '../../../core/session/session_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';

  List<Movie> get _filteredMovies {
    final activeMovies = mockMovies.where((m) => m.status == 'ACTIVE').toList();
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return activeMovies;
    }

    return activeMovies
        .where((movie) => movie.title.toLowerCase().contains(normalizedQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final featuredMovie = _filteredMovies.isNotEmpty ? _filteredMovies.first : mockMovies.first;
    final visibleMovies = _filteredMovies;
    final session = SessionProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.movie_filter_outlined, color: AppColors.primary, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'CINEMA',
              style: AppTextStyles.heading2.copyWith(letterSpacing: 1.5),
            ),
          ],
        ),
        actions: session.isAuthenticated
            ? [
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
                  icon: const Icon(Icons.notifications_none_outlined),
                ),
                IconButton(
                  tooltip: 'Profile',
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
                  icon: const Icon(Icons.person_outline),
                ),
                const SizedBox(width: AppSpacing.sm),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  ),
                  child: const Text('Sign in', style: AppTextStyles.button),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: ListView(
                  key: const Key('homeScrollView'),
                  padding: EdgeInsets.all(
                    isWide ? AppSpacing.xxl : AppSpacing.lg,
                  ),
                  children: [
                    _HomeHeader(isWide: isWide),
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      key: const Key('movieSearchField'),
                      label: 'Search active movies',
                      hint: 'Search by title',
                      prefixIcon: const Icon(Icons.search),
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _FeaturedMovie(
                      movie: featuredMovie,
                      isWide: isWide,
                      onTap: () => _openMovie(featuredMovie),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const Text('Now Showing', style: AppTextStyles.heading2),
                    const SizedBox(height: AppSpacing.lg),
                    if (visibleMovies.isEmpty)
                      const EmptyState(
                        icon: Icons.search_off_outlined,
                        title: 'No movies found',
                        message: 'Try another movie title.',
                      )
                    else if (isWide)
                      _MovieGrid(movies: visibleMovies, onMovieTap: _openMovie)
                    else
                      _MovieList(movies: visibleMovies, onMovieTap: _openMovie),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openMovie(Movie movie) {
    Navigator.pushNamed(context, AppRoutes.movieDetail, arguments: movie);
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: isWide ? Axis.horizontal : Axis.vertical,
      crossAxisAlignment: isWide
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        const Text('Good evening', style: AppTextStyles.bodySmall),
        if (isWide) const Spacer() else const SizedBox(height: AppSpacing.xs),
        if (isWide)
          const Expanded(
            child: Text(
              'Find your next movie night',
              style: AppTextStyles.display,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          const Text(
            'Find your next movie night',
            style: AppTextStyles.heading1,
          ),
      ],
    );
  }
}

class _FeaturedMovie extends StatelessWidget {
  const _FeaturedMovie({
    required this.movie,
    required this.isWide,
    required this.onTap,
  });

  final Movie movie;
  final bool isWide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusLg,
        child: SizedBox(
          height: isWide ? 480 : 520,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(imageUrl: movie.posterUrl),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.background.withValues(alpha: 0.6),
                      AppColors.background,
                    ],
                    stops: const [0.4, 0.8, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                bottom: AppSpacing.xl,
                child: _FeaturedMovieContent(movie: movie, onTap: onTap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedMovieContent extends StatelessWidget {
  const _FeaturedMovieContent({required this.movie, required this.onTap});

  final Movie movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.2),
            borderRadius: AppRadius.borderRadiusSm,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              'FEATURED',
              style: AppTextStyles.caption.copyWith(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          movie.title,
          style: AppTextStyles.display.copyWith(color: Colors.white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${movie.genre} • ${movie.durationText}',
          style: AppTextStyles.body.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Book Now',
                onPressed: onTap, // Tap the same route
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton.secondary(
                label: 'View Details',
                onPressed: onTap, 
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MovieGrid extends StatelessWidget {
  const _MovieGrid({required this.movies, required this.onMovieTap});

  final List<Movie> movies;
  final ValueChanged<Movie> onMovieTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: movies.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 340,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.lg,
      ),
      itemBuilder: (context, index) {
        final movie = movies[index];
        return MovieCard(
          title: movie.title,
          posterUrl: movie.posterUrl,
          genre: movie.genre,
          duration: movie.durationText,
          onTap: () => onMovieTap(movie),
        );
      },
    );
  }
}

class _MovieList extends StatelessWidget {
  const _MovieList({required this.movies, required this.onMovieTap});

  final List<Movie> movies;
  final ValueChanged<Movie> onMovieTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: movies.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final movie = movies[index];
          return SizedBox(
            width: 160,
            child: MovieCard(
              title: movie.title,
              posterUrl: movie.posterUrl,
              genre: movie.genre,
              duration: movie.durationText,
              onTap: () => onMovieTap(movie),
            ),
          );
        },
      ),
    );
  }
}
