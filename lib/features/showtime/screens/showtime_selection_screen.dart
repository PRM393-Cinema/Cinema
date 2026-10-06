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

class ShowtimeSelectionScreen extends StatefulWidget {
  const ShowtimeSelectionScreen({required this.catalogRepository, super.key});

  final CatalogRepository catalogRepository;

  @override
  State<ShowtimeSelectionScreen> createState() =>
      _ShowtimeSelectionScreenState();
}

class _ShowtimeSelectionScreenState extends State<ShowtimeSelectionScreen> {
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
        appBar: AppBar(title: const Text('Showtimes')),
        body: const ErrorState(
          title: 'Movie not found',
          message: 'Please return to the movie detail and try again.',
        ),
      );
    }

    final selected = _selectedShowtime;

    return Scaffold(
      appBar: AppBar(title: Text(movie.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildBody(movie, selected),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Movie movie, Showtime? selected) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadShowtimes,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _MovieHeader(movie: movie),
                const SizedBox(height: AppSpacing.xl),
                const Text('Select Showtime', style: AppTextStyles.heading2),
                const SizedBox(height: AppSpacing.md),
                ..._buildShowtimes(),
              ],
            ),
          ),
        ),
        _SelectionBar(
          showtime: selected,
          onContinue: selected == null
              ? null
              : () => _continueToSeats(movie, selected),
        ),
      ],
    );
  }

  List<Widget> _buildShowtimes() {
    if (_isLoading) {
      return const [
        SizedBox(height: AppSpacing.xxl),
        LoadingState(message: 'Loading showtimes...'),
      ];
    }

    if (_errorMessage != null) {
      return [
        ErrorState(
          title: 'Unable to load showtimes',
          message: _errorMessage!,
          onRetry: _loadShowtimes,
        ),
      ];
    }

    if (_showtimes.isEmpty) {
      return [
        EmptyState(
          icon: Icons.event_busy_outlined,
          title: 'No showtimes available',
          message: 'There are no upcoming showtimes for this movie yet.',
          action: AppButton.secondary(
            label: 'Refresh',
            onPressed: _loadShowtimes,
          ),
        ),
      ];
    }

    // Showtimes come sorted by start time; group them by day.
    final days = <DateTime, List<Showtime>>{};
    for (final showtime in _showtimes) {
      days
          .putIfAbsent(DateUtils.dateOnly(showtime.startTime), () => [])
          .add(showtime);
    }

    return [
      for (final entry in days.entries) ...[
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            formatDayHeading(entry.key),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final showtime in entry.value)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _ShowtimeCard(
              showtime: showtime,
              isSelected: _selectedShowtime?.id == showtime.id,
              onTap: () {
                if (showtime.isOpen) {
                  setState(() => _selectedShowtime = showtime);
                }
              },
            ),
          ),
      ],
    ];
  }
}

class _MovieHeader extends StatelessWidget {
  const _MovieHeader({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final details = [
      movie.durationText,
      if (movie.language.isNotEmpty) movie.language,
    ].join(' • ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppNetworkImage(
          imageUrl: movie.posterUrl,
          width: 72,
          height: 108,
          borderRadius: AppRadius.borderRadiusMd,
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movie.title,
                style: AppTextStyles.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (movie.genre.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(movie.genre, style: AppTextStyles.bodySmall),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(details, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}

// Pinned bottom bar: what is selected and the way forward.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.showtime, required this.onContinue});

  final Showtime? showtime;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final selected = showtime;

    return Container(
      width: double.infinity,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selected == null)
            const Text(
              'Choose a showtime to continue.',
              style: AppTextStyles.bodySmall,
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatDayHeading(selected.startTime)} • '
                    '${formatTime(selected.startTime)}',
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
          AppButton(label: 'Continue to Seats', onPressed: onContinue),
        ],
      ),
    );
  }
}

class _ShowtimeCard extends StatelessWidget {
  const _ShowtimeCard({
    required this.showtime,
    required this.isSelected,
    required this.onTap,
  });

  final Showtime showtime;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected
        ? AppColors.primary.withAlpha(38)
        : AppColors.surface;
    final borderColor = isSelected ? AppColors.primary : AppColors.border;
    final opacity = showtime.isOpen ? 1.0 : 0.5;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusMd,
          side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderRadiusMd,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatTime(showtime.startTime)} - ${formatTime(showtime.endTime)}',
                        style: AppTextStyles.heading2,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(showtime.roomLabel, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatVnd(showtime.price), style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.xs),
                    _StatusPill(status: showtime.status),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isOpen = status == 'OPEN';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isOpen
            ? AppColors.success.withAlpha(51)
            : AppColors.error.withAlpha(51),
        borderRadius: AppRadius.borderRadiusSm,
        border: Border.all(color: isOpen ? AppColors.success : AppColors.error),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          status,
          style: AppTextStyles.caption.copyWith(
            color: isOpen ? AppColors.success : AppColors.error,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
