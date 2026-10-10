import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/models/booking_draft.dart';
import '../../../data/repositories/booking_repository.dart';

class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({required this.bookingRepository, super.key});

  final BookingRepository bookingRepository;

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _confirmBooking(BookingDraft draft) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final booking = await widget.bookingRepository.createBooking(
        showtimeId: draft.showtime.id,
        seatIds: draft.seats.map((seat) => seat.id).toList(),
      );

      if (!mounted) return;

      // The seats are now held for this booking: leave the selection flow so
      // going back cannot create a second booking for the same seats.
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.payment(booking.id),
        (route) => route.isFirst,
        arguments: booking,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 409) {
        await _showSeatsTakenDialog(error.message);
        return;
      }
      _showError(error.message);
    } on FormatException {
      _showError('The server returned an invalid response.');
    } on Object {
      _showError('Something went wrong. Please try again.');
    }
  }

  Future<void> _showSeatsTakenDialog(String message) async {
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Seats no longer available',
          style: AppTextStyles.title,
        ),
        content: Text(
          'Some of your seats were just taken by another customer. Please choose your seats again.\n\n$message',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Choose again'),
          ),
        ],
      ),
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! BookingDraft) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Booking Summary'),
        ),
        body: const ErrorState(
          title: 'Draft not found',
          message: 'Please return and select your seats again.',
        ),
      );
    }

    final draft = args;
    final showtime = draft.showtime;
    final seatLabels = draft.seats.map((seat) => seat.label).join(', ');

    return Scaffold(
      body: CinemaBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: centeredPadding(context, AppSpacing.lg),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Booking Summary', style: AppTextStyles.heading2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: centeredPadding(context, AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SummaryCard(
                        title: 'Movie',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              draft.movie.title,
                              style: AppTextStyles.heading2,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _DetailRow(
                              icon: Icons.calendar_today_outlined,
                              text: formatLongDate(showtime.startTime),
                            ),
                            _DetailRow(
                              icon: Icons.access_time_outlined,
                              text: formatTime(showtime.startTime),
                            ),
                            _DetailRow(
                              icon: Icons.meeting_room_outlined,
                              text: showtime.roomLabel,
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
                            Text(seatLabels, style: AppTextStyles.body),
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
                                Expanded(
                                  child: Text(
                                    '${draft.ticketCount}x Ticket (${formatVnd(showtime.price)})',
                                    style: AppTextStyles.body,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  formatVnd(draft.totalPrice),
                                  style: AppTextStyles.body,
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              child: Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: AppTextStyles.heading2,
                                ),
                                Text(
                                  formatVnd(draft.totalPrice),
                                  style: AppTextStyles.heading2.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Text(
                        'Your seats will be held for 10 minutes while you pay with PayOS.',
                        style: AppTextStyles.bodySmall,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _ErrorBanner(message: _errorMessage!),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: centeredPadding(
                  context,
                  AppSpacing.lg,
                ).copyWith(top: AppSpacing.sm),
                child: AppButton(
                  label: 'Confirm Booking',
                  useGradient: true,
                  trailingIcon: Icons.arrow_forward_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting
                      ? null
                      : () => _confirmBooking(draft),
                ),
              ),
            ],
          ),
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
        CinemaPanel(
          surfaceOpacity: 0.8,
          child: SizedBox(width: double.infinity, child: child),
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
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: AppColors.error),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message, style: AppTextStyles.bodySmall)),
          ],
        ),
      ),
    );
  }
}
