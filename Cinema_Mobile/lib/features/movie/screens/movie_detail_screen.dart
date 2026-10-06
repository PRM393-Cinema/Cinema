import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/auth_guard.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/booking_draft.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/showtime.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../showtime/widgets/showtime_section.dart';

// Movie details with its upcoming showtimes, so customers pick a time here
// and go straight to the seat map.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({required this.catalogRepository, super.key});

  final CatalogRepository catalogRepository;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  Movie? _movie;
  List<Showtime> _showtimes = const [];
  bool _isLoading = true;
  String? _errorMessage;
  Showtime? _selectedShowtime;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (_movie == null && args is Movie) {
      _movie = args;
      _loadShowtimes();
    }
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

    AuthGuard.requireAuthentication(
      context,
      pendingRoute: AppRoutes.seatSelection,
      pendingArguments: args,
      onAuthenticated: () {
        Navigator.pushNamed(context, AppRoutes.seatSelection, arguments: args);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = _movie;

    if (movie == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Movie Detail')),
        body: const ErrorState(
          title: 'Movie not found',
          message: 'Please return home and select a movie again.',
        ),
      );
    }

    final selected = _selectedShowtime;

    return Scaffold(
      appBar: AppBar(title: Text(movie.title)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;

            return RefreshIndicator(
              onRefresh: _loadShowtimes,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Padding(
                      padding: EdgeInsets.all(
                        isWide ? AppSpacing.xxl : AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MovieOverview(movie: movie, isWide: isWide),
                          const SizedBox(height: AppSpacing.xxl),
                          const Text(
                            'Showtimes',
                            style: AppTextStyles.heading2,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _buildShowtimes(),
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
      return EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'No showtimes available',
        message: 'There are no upcoming showtimes for this movie yet.',
        action: AppButton.secondary(
          label: 'Refresh',
          onPressed: _loadShowtimes,
        ),
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
              width: isWide ? 220 : 116,
              height: isWide ? 330 : 174,
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

  @override
  Widget build(BuildContext context) {
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
          children: [
            if (movie.releaseYear.isNotEmpty)
              _InfoPill(label: movie.releaseYear),
            _InfoPill(label: movie.durationText),
            if (movie.language.isNotEmpty) _InfoPill(label: movie.language),
          ],
        ),
        if (movie.genre.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(movie.genre, style: AppTextStyles.title),
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
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
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

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
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
                        '${formatVnd(selected.price)} / seat',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Continue to Seats',
                  leadingIcon: Icons.event_seat_outlined,
                  onPressed: onContinue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
