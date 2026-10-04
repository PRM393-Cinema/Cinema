import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_state.dart';
import '../../../data/mock/mock_movies.dart';
import '../../../data/models/booking_draft.dart';

class BookingSummaryScreen extends StatelessWidget {
  const BookingSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! BookingDraft) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Summary')),
        body: const ErrorState(
          title: 'Draft not found',
          message: 'Please return and select your seats again.',
        ),
      );
    }

    final draft = args;
    final showtime = draft.showtime;
    final movie = mockMovies.firstWhere(
      (m) => m.id == showtime.movieId,
      orElse: () => mockMovies.first,
    );

    final dateFormat = DateFormat('EEEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    // Group seat labels by row for a clean display
    final Map<String, List<int>> seatsByRow = {};
    for (final seat in draft.seats) {
      seatsByRow.putIfAbsent(seat.row, () => []).add(seat.number);
    }

    // Sort rows and numbers
    final sortedRows = seatsByRow.keys.toList()..sort();
    for (final row in sortedRows) {
      seatsByRow[row]!.sort();
    }

    final seatLabels = sortedRows.map((row) {
      return '$row${seatsByRow[row]!.join(', ')}';
    }).join(' • ');

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Summary')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryCard(
                      title: 'Movie',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(movie.title, style: AppTextStyles.heading2),
                          const SizedBox(height: AppSpacing.sm),
                          _DetailRow(
                            icon: Icons.calendar_today_outlined,
                            text: dateFormat.format(showtime.startTime),
                          ),
                          _DetailRow(
                            icon: Icons.access_time_outlined,
                            text: timeFormat.format(showtime.startTime),
                          ),
                          _DetailRow(
                            icon: Icons.meeting_room_outlined,
                            text: 'Room: ${showtime.roomId}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SummaryCard(
                      title: 'Seats',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seatLabels,
                            style: AppTextStyles.body,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${draft.ticketCount} Ticket(s)',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SummaryCard(
                      title: 'Price Details',
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${draft.ticketCount}x Ticket (\$${showtime.price.toStringAsFixed(2)})',
                                style: AppTextStyles.body,
                              ),
                              Text(
                                '\$${draft.totalPrice.toStringAsFixed(2)}',
                                style: AppTextStyles.body,
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                            child: Divider(height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total', style: AppTextStyles.heading2),
                              Text(
                                '\$${draft.totalPrice.toStringAsFixed(2)}',
                                style: AppTextStyles.heading2.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: AppButton(
                label: 'Confirm Booking',
                onPressed: () {
                  // Navigation validation only. Real POST /api/v1/bookings not called yet.
                  Navigator.pushNamed(context, AppRoutes.payment);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.borderRadiusMd,
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: AppTextStyles.body),
          ),
        ],
      ),
    );
  }
}
