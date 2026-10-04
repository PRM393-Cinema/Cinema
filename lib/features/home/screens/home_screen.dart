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
    // For featured movie, pick the first active one, or just the first mock if none active
    final featuredMovie = _filteredMovies.isNotEmpty ? _filteredMovies.first : mockMovies.first;
    final visibleMovies = _filteredMovies;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cinema App'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.notifications),
            icon: const Icon(Icons.notifications_none_outlined),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
            icon: const Icon(Icons.person_outline),
          ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusLg,
        child: Flex(
          direction: isWide ? Axis.horizontal : Axis.vertical,
          children: [
            SizedBox(
              width: isWide ? 420 : double.infinity,
              height: isWide ? 260 : 190,
              child: AppNetworkImage(imageUrl: movie.posterUrl),
            ),
            if (isWide)
              Expanded(
                child: _FeaturedMovieContent(movie: movie, onTap: onTap),
              )
            else
              _FeaturedMovieContent(movie: movie, onTap: onTap),
          ],
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Featured', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          Text(
            movie.title,
            style: AppTextStyles.heading1,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${movie.genre} - ${movie.durationText}',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'View Details',
            leadingIcon: Icons.play_arrow_outlined,
            onPressed: onTap,
          ),
        ],
      ),
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
        maxCrossAxisExtent: 360,
        mainAxisExtent: 128,
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
      height: 144,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: movies.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final movie = movies[index];
          return SizedBox(
            width: 300,
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
