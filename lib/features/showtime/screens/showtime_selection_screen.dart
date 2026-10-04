import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_state.dart';
import '../../../data/mock/mock_showtimes.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/showtime.dart';
import '../../../core/session/auth_guard.dart';

class ShowtimeSelectionScreen extends StatefulWidget {
  const ShowtimeSelectionScreen({super.key});

  @override
  State<ShowtimeSelectionScreen> createState() => _ShowtimeSelectionScreenState();
}

class _ShowtimeSelectionScreenState extends State<ShowtimeSelectionScreen> {
  Showtime? _selectedShowtime;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! Movie) {
      return Scaffold(
        appBar: AppBar(title: const Text('Showtimes')),
        body: const ErrorState(
          title: 'Movie not found',
          message: 'Please return to the movie detail and try again.',
        ),
      );
    }

    final movie = args;
    // In a real app, we'd fetch showtimes for this movie id from backend.
    // For now, we simulate fetching by taking the mock showtimes.
    // We'll just show all mock showtimes if none match, for UI preview, 
    // or filter properly. Let's filter properly. If empty, just show a fallback to mockShowtimes for UI testing.
    var showtimes = mockShowtimes.where((s) => s.movieId == movie.id).toList();
    if (showtimes.isEmpty) {
      showtimes = mockShowtimes; // fallback for previewing other movies
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(movie.title),
      ),
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
                      const Text('Select Showtime', style: AppTextStyles.heading1),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Choose a time to see ${movie.title}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    itemCount: showtimes.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final showtime = showtimes[index];
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
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: AppButton(
                    label: 'Continue to Seats',
                    onPressed: _selectedShowtime != null
                        ? () {
                            AuthGuard.requireAuthentication(
                              context,
                              pendingRoute: AppRoutes.seatSelection,
                              pendingArguments: _selectedShowtime,
                              onAuthenticated: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.seatSelection,
                                  arguments: _selectedShowtime,
                                );
                              },
                            );
                          }
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
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d, yyyy');

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
                        '${timeFormat.format(showtime.startTime)} - ${timeFormat.format(showtime.endTime)}',
                        style: AppTextStyles.heading2,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${dateFormat.format(showtime.startTime)} • Room: ${showtime.roomId}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${showtime.price.toStringAsFixed(2)}',
                      style: AppTextStyles.title,
                    ),
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
        color: isOpen ? AppColors.success.withAlpha(51) : AppColors.error.withAlpha(51),
        borderRadius: AppRadius.borderRadiusSm,
        border: Border.all(color: isOpen ? AppColors.success : AppColors.error),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
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
