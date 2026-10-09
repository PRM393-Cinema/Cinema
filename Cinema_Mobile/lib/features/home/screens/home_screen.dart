import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
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
  final _glassBackgroundKey = GlobalKey();
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
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text.rich(
          const TextSpan(
            children: [
              TextSpan(
                text: 'COSMO',
                style: TextStyle(color: AppColors.primary),
              ),
              TextSpan(text: 'Q'),
            ],
          ),
          style: AppTextStyles.heading2.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            shadows: [
              Shadow(
                color: AppColors.primary.withValues(alpha: 0.55),
                blurRadius: 10,
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
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
      body: CinemaGlassBackground(
        key: _glassBackgroundKey,
        child: CinemaBackground(
          child: SafeArea(
            bottom: false,
            child: _buildBody(featuredMovie, visibleMovies),
          ),
        ),
      ),
      bottomNavigationBar: CinemaNavigationBar(
        selectedIndex: 0,
        backgroundKey: _glassBackgroundKey,
      ),
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
                padding: EdgeInsets.all(isWide ? AppSpacing.xxl : AppSpacing.lg)
                    .copyWith(bottom: MediaQuery.paddingOf(context).bottom),
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
                  if (featuredMovie != null && isWide) ...[
                    _FeaturedMovie(
                      movie: featuredMovie,
                      isWide: isWide,
                      onTap: () => _openMovie(featuredMovie),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Text(
                          'Now Showing',
                          style: AppTextStyles.heading2,
                        ),
                      ),
                      if (isWide)
                        Text(
                          '${visibleMovies.length} films',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
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
                  else
                    _MovieGrid(movies: visibleMovies, onMovieTap: _openMovie),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openMovie(Movie movie) {
    Navigator.pushNamed(
      context,
      AppRoutes.movieDetail(movie.id),
      arguments: movie,
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.isWide});
  final bool isWide;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: isWide ? 48 : 28),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Text(
            'Experience Premium Cinema',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Step Into '),
              TextSpan(
                text: 'CosmoQ',
                style: TextStyle(
                  color: AppColors.primary,
                  shadows: [
                    Shadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
              const TextSpan(text: ' Cinema'),
            ],
          ),
          style: AppTextStyles.heading1.copyWith(
            fontSize: isWide ? 42 : 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Discover the ultimate film screening technology. High-contrast projection, '
            'Dolby Atmos audio, and luxury reclining seats. Book your tickets below.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          width: 56,
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.primary,
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
      padding: EdgeInsets.zero,
      itemCount: movies.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
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
