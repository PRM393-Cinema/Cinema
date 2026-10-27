import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/responsive_columns.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/cinema_page.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/booking_repository.dart';
import 'my_bookings_screen.dart';
import '../widgets/booking_cancellation_dialog.dart';
import '../widgets/ticket_qr_card.dart';

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
        booking.status == BookingStatus.confirmed ||
        booking.status == BookingStatus.refundPending ||
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
      builder: (_) => BookingCancellationDialog(
        requestRefund: isPaid,
        message: isPaid
            ? 'Request a full refund of ${formatVnd(booking.totalAmount)}. '
                  'Your booking and seats remain active while staff review the request. The booking is cancelled only after the refund is completed.'
            : 'Your seats will be released for other customers.',
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
      await showBookingCancellationNotice(
        context,
        refundRequested: isPaid,
        message: isPaid
            ? 'Your refund request is pending review. Your booking remains active.'
            : 'Your seats have been released.',
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
      return CinemaPage(
        title: 'Booking Detail',
        child: const LoadingState(message: 'Loading booking...'),
      );
    }

    if (booking == null) {
      return CinemaPage(
        title: 'Booking Detail',
        child: const ErrorState(
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
    final canCancel = booking.canCancel() && !(_refund?.isRejected ?? false);
    final paidButTooLate =
        booking.status == BookingStatus.confirmed &&
        !booking.canCancel() &&
        booking.showTime != null &&
        booking.showTime!.isAfter(DateTime.now());

    final headerCard = CinemaPanel(
      surfaceOpacity: 0.8,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(
                  Icons.local_activity_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
                Text(
                  'Your booking',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                BookingStatusBadge(
                  status: booking.status,
                  checkedIn: booking.isCheckedIn,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              booking.movieTitle ?? 'Unknown Movie',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Booking code',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SelectableText(
              booking.bookingCode,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Divider(height: 1, color: AppColors.border),
            ),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: [
                _ShowtimeField(
                  icon: Icons.calendar_today_outlined,
                  label: 'Show date',
                  value: showDateStr,
                ),
                _ShowtimeField(
                  icon: Icons.schedule_outlined,
                  label: 'Show time',
                  value: showTimeStr,
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final seatsCard = _DetailSection(
      title: 'Seats & Tickets',
      icon: Icons.event_seat_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final seat in booking.seats)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    seat.seatLabel,
                    style: AppTextStyles.title.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${booking.seats.length} Ticket(s)',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
    final paymentCard = _DetailSection(
      title: 'Payment Summary',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (booking.concessions.isNotEmpty) ...[
                  Text(
                    'Snacks: ${booking.snacksText}',
                    key: const Key('bookingSnacks'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (booking.hasDiscount) ...[
                  Text(
                    'Discount: ${booking.discountText}',
                    key: const Key('bookingDiscount'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(
                  'Total Amount',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatVnd(booking.totalAmount),
                  style: AppTextStyles.heading1.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (booking.paymentId != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment ID',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${booking.paymentId}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
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
    );
    final timelineCard = _DetailSection(
      title: 'Timeline',
      icon: Icons.history_outlined,
      child: Column(
        children: [
          _TimelineRow(
            label: 'Created',
            value: formatDateTime(booking.createdAt),
          ),
          if (booking.checkedInAt case final checkedInAt?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _TimelineRow(
                label: 'Checked in',
                value: formatDateTime(checkedInAt),
              ),
            ),
          if (booking.expiresAt != null &&
              booking.status == BookingStatus.pending)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _TimelineRow(
                label: 'Expires',
                value: formatDateTime(booking.expiresAt!),
                isWarning: true,
              ),
            ),
        ],
      ),
    );
    final lateNote = Text(
      'Paid bookings can be cancelled up to '
      '${Booking.cancelBeforeShowtime.inHours} hours before the show. '
      'Please contact the cinema for help.',
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
    );
    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canPay) ...[
          AppButton(
            label: 'Pay Now',
            useGradient: true,
            leadingIcon: Icons.qr_code_2_rounded,
            onPressed: _isCancelling ? null : () => _payNow(booking),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (canCancel)
          AppButton.danger(
            label: booking.status == BookingStatus.confirmed
                ? 'Request refund'
                : 'Cancel Booking',
            isLoading: _isCancelling,
            onPressed: _isCancelling ? null : () => _cancelBooking(booking),
          ),
      ],
    );
    final hasActions = canPay || canCancel;
    final desktop = isDesktopLayout(context);
    // Paid tickets carry the QR code staff scan at the cinema.
    final hasTicket = booking.status == BookingStatus.confirmed;

    return CinemaPage(
      title: 'Booking Detail',
      width: PageWidth.page,
      child: Column(
        children: [
          if (_isRefreshing) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: pagePadding(context, AppSpacing.xl),
                // Website: the ticket on the left, payment and actions on
                // the right.
                child: ResponsiveColumns(
                  main: [
                    headerCard,
                    if (hasTicket && !desktop) ...[
                      const SizedBox(height: AppSpacing.xl),
                      TicketQrCard(booking: booking),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    seatsCard,
                    const SizedBox(height: AppSpacing.xl),
                    if (desktop) timelineCard,
                  ],
                  side: [
                    if (hasTicket && desktop) ...[
                      TicketQrCard(booking: booking),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    paymentCard,
                    if (!desktop) ...[
                      const SizedBox(height: AppSpacing.xl),
                      timelineCard,
                    ],
                    if (paidButTooLate) ...[
                      const SizedBox(height: AppSpacing.lg),
                      lateNote,
                    ],
                    if (desktop && hasActions) ...[
                      const SizedBox(height: AppSpacing.xl),
                      actions,
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Bottom Actions
          if (!desktop && hasActions)
            Padding(
              padding: centeredPadding(context, AppSpacing.lg),
              child: actions,
            ),
        ],
      ),
    );
  }
}

class _RefundRow extends StatelessWidget {
  const _RefundRow({required this.refund});

  final Refund refund;

  @override
  Widget build(BuildContext context) {
    if (refund.isRejected) {
      return Container(
        margin: const EdgeInsets.only(top: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.error,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Refund request rejected',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (refund.note != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Rejection reason',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SelectableText(
                refund.note!,
                style: AppTextStyles.body.copyWith(height: 1.5),
              ),
            ],
          ],
        ),
      );
    }
    final label = refund.isCompleted
        ? 'Refunded ${formatVnd(refund.amount)}'
        : 'Refund of ${formatVnd(refund.amount)} in progress';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Refund',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: AppTextStyles.bodySmall.copyWith(
                  color: refund.isCompleted
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CinemaPanel(
      surfaceOpacity: 0.8,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTextStyles.title)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
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
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTextStyles.bodySmall.copyWith(
              color: isWarning ? AppColors.warning : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShowtimeField extends StatelessWidget {
  const _ShowtimeField({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(value, style: AppTextStyles.body),
            ],
          ),
        ),
      ],
    );
  }
}
