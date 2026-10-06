import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/movie.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../movie/widgets/movie_card.dart';
import '../../../core/session/session_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.catalogRepository, super.key});

  final CatalogRepository catalogRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  List<Movie> _movies = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    setState(() {
      _isLoading = _movies.isEmpty;
      _errorMessage = null;
    });

    try {
      final movies = await widget.catalogRepository.getNowShowingMovies();
      if (!mounted) return;
      setState(() {
        _movies = movies;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _showError(error.message);
    } on FormatException {
      _showError('The server returned an invalid response.');
    } on Object {
      _showError('Something went wrong. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  List<Movie> get _filteredMovies {
    final activeMovies = _movies.where((m) => m.status == 'ACTIVE').toList();
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
    final visibleMovies = _filteredMovies;
    final featuredMovie = visibleMovies.isNotEmpty
        ? visibleMovies.first
        : (_movies.isNotEmpty ? _movies.first : null);
    final session = SessionProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(
              Icons.movie_filter_outlined,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.sm),
            // Narrow phones with every action shown leave little room.
            Flexible(
              child: Text(
                'CINEMA',
                style: AppTextStyles.heading2.copyWith(letterSpacing: 1.5),
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
          ],
        ),
        actions: session.isAuthenticated
            ? [
                IconButton(
                  tooltip: 'My bookings',
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.myBookings),
                  icon: const Icon(Icons.confirmation_number_outlined),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.notifications),
                  icon: const Icon(Icons.notifications_none_outlined),
                ),
                IconButton(
                  tooltip: 'Profile',
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.profile),
                  icon: const Icon(Icons.person_outline),
                ),
                const SizedBox(width: AppSpacing.sm),
              ]
            : [
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.login),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  child: const Text('Sign in', style: AppTextStyles.button),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
      ),
      body: SafeArea(child: _buildBody(featuredMovie, visibleMovies)),
    );
  }

  Widget _buildBody(Movie? featuredMovie, List<Movie> visibleMovies) {
    if (_isLoading) {
      return const LoadingState(message: 'Loading movies...');
    }

    if (_errorMessage != null && _movies.isEmpty) {
      return ErrorState(
        title: 'Unable to load movies',
        message: _errorMessage!,
        onRetry: _loadMovies,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMovies,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ListView(
                key: const Key('homeScrollView'),
                physics: const AlwaysScrollableScrollPhysics(),
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
                  if (featuredMovie != null) ...[
                    _FeaturedMovie(
                      movie: featuredMovie,
                      isWide: isWide,
                      onTap: () => _openMovie(featuredMovie),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                  const Text('Now Showing', style: AppTextStyles.heading2),
                  const SizedBox(height: AppSpacing.lg),
                  if (_movies.isEmpty)
                    const EmptyState(
                      icon: Icons.movie_outlined,
                      title: 'No movies showing',
                      message: 'Please check back later.',
                    )
                  else if (visibleMovies.isEmpty)
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
