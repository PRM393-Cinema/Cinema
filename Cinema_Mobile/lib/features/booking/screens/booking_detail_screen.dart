import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/cinema_page.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/booking_repository.dart';
import '../widgets/booking_detail_content.dart';
import '../widgets/booking_cancellation_dialog.dart';
import '../widgets/seat_hold_timer.dart';
import '../widgets/ticket_share_actions.dart';
import '../../../data/repositories/catalog_repository.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({
    required this.bookingRepository,
    this.bookingId,
    this.catalogRepository,
    this.shareTicket,
    super.key,
  });

  final BookingRepository bookingRepository;

  // Reads the show's end for "Add to calendar".
  final CatalogRepository? catalogRepository;

  // The share sheet; null uses the device's.
  final TextSharer? shareTicket;

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
  Timer? _holdTimer;

  void _watchHold() {
    _holdTimer?.cancel();
    final booking = _booking;
    if (booking == null ||
        booking.expiresAt == null ||
        !booking.isAwaitingPayment()) {
      return;
    }
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (_booking?.isAwaitingPayment() != true) timer.cancel();
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (_booking == null && args is Booking) {
      _booking = args;
      _watchHold();
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
      _watchHold();
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
      _watchHold();
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
      _watchHold();
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
    if (!booking.isAwaitingPayment()) {
      setState(() {});
      return;
    }
    await Navigator.pushNamed(
      context,
      AppRoutes.payment(booking.id),
      arguments: booking,
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: bookingDetailTheme(Theme.of(context)),
    child: Builder(builder: _buildPage),
  );

  Widget _buildPage(BuildContext context) {
    final booking = _booking;
    final desktop = isDesktopLayout(context);
    final canPay = booking?.isAwaitingPayment() ?? false;
    final canCancel =
        booking != null &&
        booking.canCancel() &&
        !(_refund?.isRejected ?? false);
    final paidButTooLate =
        booking != null &&
        booking.status == BookingStatus.confirmed &&
        !booking.canCancel() &&
        booking.showTime != null &&
        booking.showTime!.isAfter(DateTime.now());
    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canPay) ...[
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(44, 48),
              textStyle: const TextStyle(
                fontFamily: 'BookingInter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            label: const Text('Pay Now'),
            icon: const Icon(BookingDetailIcons.qr, size: 16),
            onPressed: _isCancelling ? null : () => _payNow(booking!),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (canCancel)
          OutlinedButton.icon(
            label: Text(
              booking.status == BookingStatus.confirmed
                  ? 'Request refund'
                  : 'Cancel Booking',
            ),
            icon: _isCancelling
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(BookingDetailIcons.refund, size: 16),
            onPressed: _isCancelling ? null : () => _cancelBooking(booking),
          ),
      ],
    );
    final hasActions = canPay || canCancel;
    return Scaffold(
      backgroundColor: desktop ? Colors.transparent : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: pagePadding(context, AppSpacing.lg),
              child: CinemaPageHeader(
                title: 'Booking Detail',
                subtitle: 'Tickets, payment and booking activity.',
                actions: [
                  if (booking != null)
                    IconButton(
                      tooltip: 'Refresh booking',
                      onPressed: _isRefreshing ? null : _refresh,
                      icon: const Icon(BookingDetailIcons.refund),
                    ),
                ],
              ),
            ),
            if (_isRefreshing) const LinearProgressIndicator(minHeight: 2),
            if (booking?.status == BookingStatus.pending)
              Padding(
                padding: pagePadding(context, AppSpacing.sm),
                child: SeatHoldTimer(
                  remaining: booking!.expiresAt?.difference(DateTime.now()),
                  expired: booking.isHoldExpired(),
                ),
              ),
            Expanded(
              child: booking == null
                  ? (_isLoadingBooking
                        ? const LoadingState(message: 'Loading booking...')
                        : const ErrorState(
                            title: 'Booking not found',
                            message: 'The booking details could not be loaded.',
                          ))
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: SingleChildScrollView(
                        key: const Key('bookingDetailScroll'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: pagePadding(context, AppSpacing.xl),
                        child: BookingDetailContent(
                          booking: booking,
                          refund: _refund,
                          actions: desktop && hasActions ? actions : null,
                          shareActions: TicketShareActions(
                            booking: booking,
                            catalogRepository: widget.catalogRepository,
                            share:
                                widget.shareTicket ??
                                TicketShareActions.defaultShare,
                          ),
                          lateNote: paidButTooLate
                              ? Text(
                                  'Paid bookings can be cancelled up to '
                                  '${Booking.cancelBeforeShowtime.inHours} hours before the show. '
                                  'Please contact the cinema for help.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                )
                              : null,
                        ),
                      ),
                    ),
            ),
            if (!desktop && hasActions)
              Padding(
                padding: centeredPadding(context, AppSpacing.lg),
                child: actions,
              ),
          ],
        ),
      ),
    );
  }
}
