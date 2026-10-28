import 'package:flutter/material.dart';

import '../../../core/widgets/trailer_player.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/cinema_page.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/models/booking_draft.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/showtime.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../seat/widgets/seat_type_style.dart';
import '../../showtime/widgets/showtime_section.dart';
import '../../../core/widgets/age_rating_badge.dart';
import '../../review/widgets/review_widgets.dart';

// Movie details with its upcoming showtimes, so customers pick a time here
// and go straight to the seat map.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({
    required this.catalogRepository,
    required this.bookingRepository,
    this.movieId,
    super.key,
  });

  final CatalogRepository catalogRepository;
  final BookingRepository bookingRepository;

  // Set when the screen is opened from its URL: the movie is loaded by id.
  final int? movieId;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  Movie? _movie;

  // The release date of a movie that is not out yet.
  DateTime? get _comingSoonDate {
    final movie = _movie;
    return movie != null && movie.isComingSoon() ? movie.releaseDate : null;
  }

  List<Showtime> _showtimes = const [];
  bool _isLoading = true;
  String? _errorMessage;
  Showtime? _selectedShowtime;
  bool _movieRequested = false;
  bool _isLoadingMovie = false;
  String? _movieError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (_movie == null && args is Movie) {
      _movie = args;
      _loadShowtimes();
    } else if (_movie == null && !_movieRequested && widget.movieId != null) {
      _movieRequested = true;
      _isLoadingMovie = true;
      _loadMovie();
    }
  }

  // Opened from its URL (web refresh or shared link): load the movie first.
  Future<void> _loadMovie() async {
    try {
      final movie = await widget.catalogRepository.getMovie(widget.movieId!);
      if (!mounted) return;
      setState(() {
        _movie = movie;
        _isLoadingMovie = false;
      });
      await _loadShowtimes();
    } on ApiException catch (error) {
      _showMovieError(error.statusCode == 404 ? null : error.message);
    } on FormatException {
      _showMovieError('The server returned an invalid response.');
    } on Object {
      _showMovieError('Something went wrong. Please try again.');
    }
  }

  void _retryMovie() {
    setState(() {
      _isLoadingMovie = true;
      _movieError = null;
    });
    _loadMovie();
  }

  // A null message means the movie does not exist.
  void _showMovieError(String? message) {
    if (!mounted) return;
    setState(() {
      _isLoadingMovie = false;
      _movieError = message;
    });
  }

  Future<void> _loadShowtimes() async {
    final movie = _movie;
    if (movie == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final showtimes = await widget.catalogRepository.getOpenShowtimes(
        movie.id,
      );
      if (!mounted) return;
      setState(() {
        _showtimes = showtimes;
        _isLoading = false;
        if (!showtimes.any((s) => s.id == _selectedShowtime?.id)) {
          _selectedShowtime = null;
        }
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

  void _continueToSeats(Movie movie, Showtime showtime) {
    final args = SeatSelectionArgs(movie: movie, showtime: showtime);

    final route = AppRoutes.seatSelection(showtime.id);

    Navigator.pushNamed(context, route, arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    final movie = _movie;

    if (movie == null) {
      final error = _movieError;
      return CinemaPage(
        title: 'Movie Detail',
        child: _isLoadingMovie
            ? const LoadingState(message: 'Loading movie...')
            : error != null
            ? ErrorState(
                title: 'Unable to load the movie',
                message: error,
                onRetry: _retryMovie,
              )
            : const ErrorState(
                title: 'Movie not found',
                message: 'Please return home and select a movie again.',
              ),
      );
    }

    final selected = _selectedShowtime;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Movie Detail')),
      body: CinemaBackground(
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              final desktop = isDesktopLayout(context);
              // On the website the page lines up with the navigation bar.
              final side = desktop
                  ? AppSpacing.lg
                  : (isWide ? AppSpacing.xxl : AppSpacing.lg);

              return RefreshIndicator(
                onRefresh: _loadShowtimes,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: desktop
                            ? pageMaxWidth + 2 * AppSpacing.lg
                            : 1040,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          side,
                          AppSpacing.xl,
                          side,
                          AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CinemaPanel(
                              child: _MovieOverview(
                                movie: movie,
                                isWide: isWide,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            const Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Showtimes',
                                  style: AppTextStyles.heading2,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'Choose your cinema moment.',
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _buildShowtimes(),
                            const SizedBox(height: AppSpacing.xxl),
                            MovieReviewsSection(
                              movie: movie,
                              repository: widget.bookingRepository,
                              load: () => widget.catalogRepository
                                  .getMovieReviews(movie.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: _SelectionBar(
        showtime: selected,
        onContinue: selected == null
            ? null
            : () => _continueToSeats(movie, selected),
      ),
    );
  }

  Widget _buildShowtimes() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: LoadingState(message: 'Loading showtimes...'),
      );
    }

    if (_errorMessage != null) {
      return ErrorState(
        title: 'Unable to load showtimes',
        message: _errorMessage!,
        onRetry: _loadShowtimes,
      );
    }

    if (_showtimes.isEmpty) {
      final release = _comingSoonDate;
      return EmptyState(
        icon: Icons.event_busy_outlined,
        title: release == null
            ? 'No showtimes available'
            : 'Opens ${formatDate(release)}',
        message: release == null
            ? 'There are no upcoming showtimes for this movie yet.'
            : 'This movie is coming soon. Showtimes will be added closer '
                  'to the release.',
      );
    }

    return ShowtimeSection(
      showtimes: _showtimes,
      selectedShowtimeId: _selectedShowtime?.id,
      onSelected: (showtime) {
        if (showtime.isOpen) {
          setState(() => _selectedShowtime = showtime);
        }
      },
    );
  }
}

class _MovieOverview extends StatelessWidget {
  const _MovieOverview({required this.movie, required this.isWide});

  final Movie movie;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final synopsis = movie.description.isEmpty
        ? null
        : _Synopsis(description: movie.description);

    // Poster beside the facts keeps the title and details on the first
    // screen. Wide screens also put the synopsis in that column.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppNetworkImage(
              imageUrl: movie.posterUrl,
              width: isWide ? 220 : 96,
              height: isWide ? 330 : 144,
              borderRadius: AppRadius.borderRadiusLg,
            ),
            SizedBox(width: isWide ? AppSpacing.xxl : AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MovieFacts(movie: movie, isWide: isWide),
                  if (isWide && synopsis != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    synopsis,
                  ],
                ],
              ),
            ),
          ],
        ),
        if (!isWide && synopsis != null) ...[
          const SizedBox(height: AppSpacing.xl),
          synopsis,
        ],
      ],
    );
  }
}

class _MovieFacts extends StatelessWidget {
  const _MovieFacts({required this.movie, required this.isWide});

  final Movie movie;
  final bool isWide;

  Uri? get _trailer {
    final uri = Uri.tryParse(movie.trailerUrl.trim());
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
        ? uri
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final trailer = _trailer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          movie.title,
          style: isWide ? AppTextStyles.display : AppTextStyles.heading2,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AgeRatingBadge(rating: movie.ageRating, large: true),
            if (movie.isComingSoon())
              _InfoPill(
                key: const Key('comingSoonPill'),
                label: 'Coming ${formatDate(movie.releaseDate!)}',
              )
            else if (movie.releaseYear.isNotEmpty)
              _InfoPill(label: movie.releaseYear),
            _InfoPill(label: movie.durationText),
            if (movie.language.isNotEmpty) _InfoPill(label: movie.language),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${movie.ageRating.code}: ${movie.ageRating.meaning}',
          key: const Key('ageRatingMeaning'),
          style: AppTextStyles.bodySmall.copyWith(color: movie.ageRating.color),
        ),
        if (movie.genre.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(movie.genre, style: AppTextStyles.title),
        ],
        if (movie.director.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Director: ${movie.director}',
            key: const Key('movieDirector'),
            style: AppTextStyles.body,
          ),
        ],
        if (movie.cast.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Cast: ${movie.cast}',
            key: const Key('movieCast'),
            style: AppTextStyles.bodySmall,
          ),
        ],
        if (trailer != null) ...[
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            key: const Key('watchTrailer'),
            onPressed: () => showMovieTrailer(context, trailer, movie.title),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Watch trailer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warning,
              side: const BorderSide(color: AppColors.warning),
            ),
          ),
        ],
      ],
    );
  }
}

class _Synopsis extends StatelessWidget {
  const _Synopsis({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Synopsis', style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Text(description, style: AppTextStyles.body),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: AppRadius.borderRadiusSm,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Text(label, style: AppTextStyles.caption),
      ),
    );
  }
}

// Pinned bottom bar: the chosen showtime and the way to the seat map.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.showtime, required this.onContinue});

  final Showtime? showtime;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final selected = showtime;
    if (isDesktopLayout(context)) return _desktop(context, selected);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: SafeArea(
        top: false,
        child: CinemaPanel(
          padding: const EdgeInsets.all(AppSpacing.md),
          surfaceOpacity: 0.72,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (selected == null)
                    const Text(
                      'Choose a showtime to continue.',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${formatShortDate(selected.startTime)} • '
                            '${formatTime(selected.startTime)} • '
                            '${selected.roomLabel}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          seatPriceLabel(selected),
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Continue to Seats',
                    leadingIcon: Icons.event_seat_outlined,
                    useGradient: true,
                    onPressed: onContinue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Website: one row as wide as the page, the button on the right.
  Widget _desktop(BuildContext context, Showtime? selected) => Padding(
    padding: centeredPadding(
      context,
      AppSpacing.lg,
      maxWidth: pageMaxWidth,
    ).copyWith(top: AppSpacing.sm, bottom: AppSpacing.md),
    child: CinemaPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      surfaceOpacity: 0.85,
      child: Row(
        children: [
          Expanded(
            child: selected == null
                ? const Text(
                    'Choose a showtime to continue.',
                    style: AppTextStyles.body,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${formatShortDate(selected.startTime)} • '
                        '${formatTime(selected.startTime)} • '
                        '${selected.roomLabel}',
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        seatPriceLabel(selected),
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: 280,
            child: AppButton(
              label: 'Continue to Seats',
              leadingIcon: Icons.event_seat_outlined,
              useGradient: true,
              onPressed: onContinue,
            ),
          ),
        ],
      ),
    ),
  );
}
