import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/booking.dart';

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! Booking) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Detail')),
        body: const ErrorState(
          title: 'Booking not found',
          message: 'The booking details could not be loaded.',
        ),
      );
    }

    final booking = args;
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final fullDateTimeFormat = DateFormat('MMM d, yyyy • h:mm a');

    final String showDateStr = booking.showTime != null
        ? dateFormat.format(booking.showTime!)
        : 'TBA';
    final String showTimeStr = booking.showTime != null
        ? timeFormat.format(booking.showTime!)
        : 'TBA';

    final seatLabels = booking.seats.map((s) => s.seatLabel).join(', ');

    // Cancellation rule: Customer can cancel PENDING.
    // They can also cancel CONFIRMED if before showtime (we'll roughly allow it if showTime > now).
    final bool isFuture = booking.showTime != null &&
        booking.showTime!.isAfter(DateTime.now());
    
    final bool canCancel = booking.status == BookingStatus.pending ||
        (booking.status == BookingStatus.confirmed && isFuture);

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Detail')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Card
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.borderRadiusMd,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Code: ${booking.bookingCode}',
                                  style: AppTextStyles.caption,
                                ),
                                _BookingStatusBadge(status: booking.status),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              booking.movieTitle ?? 'Unknown Movie',
                              style: AppTextStyles.heading2,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 20, color: AppColors.textSecondary),
                                const SizedBox(width: AppSpacing.sm),
                                Text(showDateStr, style: AppTextStyles.body),
                                const SizedBox(width: AppSpacing.lg),
                                const Icon(Icons.access_time,
                                    size: 20, color: AppColors.textSecondary),
                                const SizedBox(width: AppSpacing.sm),
                                Text(showTimeStr, style: AppTextStyles.body),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Seats Card
                    _DetailSection(
                      title: 'Seats & Tickets',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(seatLabels, style: AppTextStyles.body),
                          const SizedBox(height: AppSpacing.xs),
                          Text('${booking.seats.length} Ticket(s)',
                              style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Price Card
                    _DetailSection(
                      title: 'Payment Summary',
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount',
                                  style: AppTextStyles.body),
                              Text(
                                '\$${booking.totalAmount.toStringAsFixed(2)}',
                                style: AppTextStyles.title,
                              ),
                            ],
                          ),
                          if (booking.paymentId != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Payment ID',
                                    style: AppTextStyles.bodySmall),
                                Text(booking.paymentId!,
                                    style: AppTextStyles.caption),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Timeline Card
                    _DetailSection(
                      title: 'Timeline',
                      child: Column(
                        children: [
                          _TimelineRow(
                            label: 'Created',
                            value: fullDateTimeFormat.format(booking.createdAt),
                          ),
                          if (booking.expiresAt != null &&
                              booking.status == BookingStatus.pending)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.sm),
                              child: _TimelineRow(
                                label: 'Expires',
                                value: fullDateTimeFormat
                                    .format(booking.expiresAt!),
                                isWarning: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions
            if (canCancel)
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: AppButton.danger(
                  label: 'Cancel Booking',
                  onPressed: () {
                    // Show confirmation dialog for UI review
                    _showCancelDialog(context);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel Booking?', style: AppTextStyles.title),
        content: const Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No, Keep It',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              // Real API integration would happen here
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cancellation requested (Mock)')),
              );
            },
            child: const Text('Yes, Cancel',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

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

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  final String label;
  final String value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(
            color: isWarning ? AppColors.warning : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _BookingStatusBadge extends StatelessWidget {
  const _BookingStatusBadge({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final String label;
    final StatusBadgeVariant variant;

    switch (status) {
      case BookingStatus.pending:
        label = 'Pending';
        variant = StatusBadgeVariant.warning;
        break;
      case BookingStatus.confirmed:
        label = 'Confirmed';
        variant = StatusBadgeVariant.success;
        break;
      case BookingStatus.cancelled:
        label = 'Cancelled';
        variant = StatusBadgeVariant.error;
        break;
      case BookingStatus.expired:
        label = 'Expired';
        variant = StatusBadgeVariant.neutral;
        break;
    }

    return StatusBadge(label: label, variant: variant);
  }
}
