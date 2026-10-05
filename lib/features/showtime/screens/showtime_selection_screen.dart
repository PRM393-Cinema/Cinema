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

    return Scaffold(
      appBar: AppBar(title: Text(movie.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Showtime',
                        style: AppTextStyles.heading1,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Choose a time to see ${movie.title}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildShowtimes()),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: AppButton(
                    label: 'Continue to Seats',
                    onPressed: _selectedShowtime != null
                        ? () => _continueToSeats(movie, _selectedShowtime!)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShowtimes() {
    if (_isLoading) {
      return const LoadingState(message: 'Loading showtimes...');
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

    return RefreshIndicator(
      onRefresh: _loadShowtimes,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _showtimes.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final showtime = _showtimes[index];
          final isSelected = _selectedShowtime?.id == showtime.id;
          return _ShowtimeCard(
            showtime: showtime,
            isSelected: isSelected,
            onTap: () {
              if (showtime.isOpen) {
                setState(() {
                  _selectedShowtime = showtime;
                });
              }
            },
          );
        },
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
                      Text(
                        '${formatDate(showtime.startTime)} • ${showtime.roomLabel}',
                        style: AppTextStyles.bodySmall,
                      ),
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
