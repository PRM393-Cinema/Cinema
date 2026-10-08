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
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/booking_repository.dart';
import 'my_bookings_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({
    required this.bookingRepository,
    this.bookingId,
    super.key,
  });

  final BookingRepository bookingRepository;

  // Set when the screen is opened from its URL: the booking is loaded by id.
  final int? bookingId;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Booking? _booking;
  bool _bookingRequested = false;
  bool _isLoadingBooking = false;
  Refund? _refund;
  bool _isRefreshing = false;
  bool _isCancelling = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (_booking == null && args is Booking) {
      _booking = args;
      _refresh();
    } else if (_booking == null &&
        !_bookingRequested &&
        widget.bookingId != null) {
      _bookingRequested = true;
      _isLoadingBooking = true;
      _loadBooking(widget.bookingId!);
    }
  }

  // Opened from its URL (web refresh or shared link).
  Future<void> _loadBooking(int bookingId) async {
    try {
      final booking = await widget.bookingRepository.getBooking(bookingId);
      final refund = await _loadRefund(booking);
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _refund = refund;
        _isLoadingBooking = false;
      });
    } on Object {
      // Shown as "Booking not found".
      if (mounted) setState(() => _isLoadingBooking = false);
    }
  }

  // The list may be stale (payment confirmed, hold expired...): reload the
  // booking and, for cancelled paid bookings, the refund status.
  Future<void> _refresh() async {
    final booking = _booking;
    if (booking == null) return;

    setState(() => _isRefreshing = true);

    try {
      final latest = await widget.bookingRepository.getBooking(booking.id);
      final refund = await _loadRefund(latest);
      if (!mounted) return;
      setState(() {
        _booking = latest;
        _refund = refund;
        _isRefreshing = false;
      });
    } on ApiException {
      if (mounted) setState(() => _isRefreshing = false);
    } on Object {
      // Keep showing the booking we already have.
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // Only cancelled or expired paid bookings can have a refund. A failed
  // lookup just hides the refund row.
  Future<Refund?> _loadRefund(Booking booking) async {
    final paymentId = booking.paymentId;
    final mayHaveRefund =
        booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.expired;
    if (paymentId == null || !mayHaveRefund) return null;

    try {
      return await widget.bookingRepository.getRefund(paymentId);
    } on ApiException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _cancelBooking(Booking booking) async {
    final isPaid = booking.status == BookingStatus.confirmed;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel Booking?', style: AppTextStyles.title),
        content: Text(
          isPaid
              ? 'You will receive a full refund of ${formatVnd(booking.totalAmount)}. '
                    'The cinema transfers the money back and emails you when it is done.'
              : 'Your seats will be released for other customers.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'No, Keep It',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);

    try {
      final cancelled = await widget.bookingRepository.cancelBooking(
        booking.id,
      );
      if (!mounted) return;

      setState(() {
        _booking = cancelled;
        _isCancelling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPaid
                ? 'Booking cancelled. Your refund has been requested.'
                : 'Booking cancelled.',
          ),
        ),
      );
      // The refund request is created in the background (RabbitMQ).
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) await _refresh();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  Future<void> _payNow(Booking booking) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.payment(booking.id),
      arguments: booking,
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;

    if (booking == null && _isLoadingBooking) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Detail')),
        body: const LoadingState(message: 'Loading booking...'),
      );
    }

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Detail')),
        body: const ErrorState(
          title: 'Booking not found',
          message: 'The booking details could not be loaded.',
        ),
      );
    }

    final String showDateStr = booking.showTime != null
        ? formatDate(booking.showTime!)
        : 'TBA';
    final String showTimeStr = booking.showTime != null
        ? formatTime(booking.showTime!)
        : 'TBA';

    final canPay = booking.isAwaitingPayment();
    final canCancel = booking.canCancel();
    final paidButTooLate =
        booking.status == BookingStatus.confirmed &&
        !canCancel &&
        booking.showTime != null &&
        booking.showTime!.isAfter(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Detail'),
        bottom: _isRefreshing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: centeredPadding(context, AppSpacing.xl),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Code: ${booking.bookingCode}',
                                      style: AppTextStyles.caption,
                                    ),
                                  ),
                                  BookingStatusBadge(status: booking.status),
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
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(showDateStr, style: AppTextStyles.body),
                                  const SizedBox(width: AppSpacing.lg),
                                  const Icon(
                                    Icons.access_time,
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
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
                            Text(booking.seatLabels, style: AppTextStyles.body),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${booking.seats.length} Ticket(s)',
                              style: AppTextStyles.bodySmall,
                            ),
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
                                const Text(
                                  'Total Amount',
                                  style: AppTextStyles.body,
                                ),
                                Text(
                                  formatVnd(booking.totalAmount),
                                  style: AppTextStyles.title,
                                ),
                              ],
                            ),
                            if (booking.paymentId != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Payment ID',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                  Text(
                                    '${booking.paymentId}',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ],
                            if (_refund != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              _RefundRow(refund: _refund!),
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
                              value: formatDateTime(booking.createdAt),
                            ),
                            if (booking.expiresAt != null &&
                                booking.status == BookingStatus.pending)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.sm,
                                ),
                                child: _TimelineRow(
                                  label: 'Expires',
                                  value: formatDateTime(booking.expiresAt!),
                                  isWarning: true,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (paidButTooLate) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Paid bookings can be cancelled up to '
                          '${Booking.cancelBeforeShowtime.inHours} hours before the show. '
                          'Please contact the cinema for help.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Actions
            if (canPay || canCancel)
              Container(
                width: double.infinity,
                padding: centeredPadding(context, AppSpacing.xl),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (canPay) ...[
                      AppButton(
                        label: 'Pay Now',
                        onPressed: _isCancelling
                            ? null
                            : () => _payNow(booking),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (canCancel)
                      AppButton.danger(
                        label: 'Cancel Booking',
                        isLoading: _isCancelling,
                        onPressed: _isCancelling
                            ? null
                            : () => _cancelBooking(booking),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RefundRow extends StatelessWidget {
  const _RefundRow({required this.refund});

  final Refund refund;

  @override
  Widget build(BuildContext context) {
    final label = refund.isCompleted
        ? 'Refunded ${formatVnd(refund.amount)}'
        : 'Refund of ${formatVnd(refund.amount)} in progress';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Refund', style: AppTextStyles.bodySmall),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: AppTextStyles.caption.copyWith(
              color: refund.isCompleted ? AppColors.success : AppColors.warning,
            ),
          ),
        ),
      ],
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
            child: SizedBox(width: double.infinity, child: child),
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
