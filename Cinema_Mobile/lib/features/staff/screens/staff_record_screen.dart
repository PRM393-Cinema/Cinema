import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/session/roles.dart';
import '../../../core/session/session_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/top_notice.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/payment.dart';
import '../../../data/models/room.dart';
import '../../../data/models/seat.dart';
import '../../../data/models/showtime.dart';
import '../../../data/services/staff_service.dart';
import '../../admin/widgets/admin_page.dart';
import '../../seat/widgets/seat_type_style.dart';
import '../widgets/room_seat_map.dart';
import '../widgets/staff_feedback.dart';

class StaffRecordScreen extends StatefulWidget {
  const StaffRecordScreen({
    required this.service,
    required this.kind,
    required this.id,
    super.key,
  });
  final StaffService service;
  final String kind;
  final int id;
  @override
  State<StaffRecordScreen> createState() => _StaffRecordScreenState();
}

class _StaffRecordScreenState extends State<StaffRecordScreen> {
  // A room's seat map follows changes made by other staff while it is open.
  static const _liveInterval = Duration(seconds: 5);
  static const _highlightFor = Duration(seconds: 4);

  Object? _item;
  List<Seat> _seats = [];
  List<PaymentInfo> _payments = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _liveTimer;
  Timer? _highlightTimer;
  bool _refreshing = false;
  bool _liveFailed = false;
  DateTime? _updatedAt;
  Set<int> _newSeatIds = {};

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.kind == 'rooms') {
      _liveTimer = Timer.periodic(_liveInterval, (_) => _refreshRoom());
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshRoom() async {
    if (_loading || _busy || _refreshing || _item is! Room) return;
    _refreshing = true;
    try {
      final room = await widget.service.room(widget.id);
      final seats = await widget.service.seats(widget.id);
      if (!mounted || _busy) return;
      _showSeats(seats, room: room);
      if (_liveFailed) setState(() => _liveFailed = false);
    } on Object {
      if (mounted && !_liveFailed) setState(() => _liveFailed = true);
    } finally {
      _refreshing = false;
    }
  }

  // Shows a newer seat map; seats that were not on the old one glow for a
  // few seconds.
  void _showSeats(List<Seat> seats, {Room? room}) {
    final known = {for (final seat in _seats) seat.id};
    final added = {
      for (final seat in seats)
        if (!known.contains(seat.id)) seat.id,
    };
    setState(() {
      _seats = seats;
      if (room != null) _item = room;
      _updatedAt = DateTime.now();
      if (known.isNotEmpty && added.isNotEmpty) _newSeatIds = added;
    });
    if (known.isNotEmpty && added.isNotEmpty) {
      _highlightTimer?.cancel();
      _highlightTimer = Timer(_highlightFor, () {
        if (mounted) setState(() => _newSeatIds = {});
      });
    }
  }

  void _notice(String message) =>
      showTopNotice(Overlay.of(context, rootOverlay: true), message);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = switch (widget.kind) {
        'bookings' => await widget.service.booking(widget.id),
        'showtimes' => await widget.service.showtime(widget.id),
        'rooms' => await widget.service.room(widget.id),
        'payments' => await widget.service.payment(widget.id),
        _ => await widget.service.refund(widget.id),
      };
      final seats = item is Room
          ? await widget.service.seats(item.id)
          : <Seat>[];
      final payments = item is Booking
          ? (await widget.service.payments(bookingId: item.id)).items
          : <PaymentInfo>[];
      if (mounted) {
        setState(() {
          _item = item;
          _seats = seats;
          _payments = payments;
          _updatedAt = DateTime.now();
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(
    Future<void> Function() action,
    String message, {
    bool cancelled = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      await staffSuccess(context, message, cancelled: cancelled);
      if (mounted) await _load();
    } on _StaffActionCancelled {
      return;
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelBooking(Booking booking) async {
    final reason = await staffInput(context, 'Cancel booking', 'Reason');
    if (reason == null || !mounted) return;
    if (!await staffConfirm(
          context,
          'Cancel this booking?',
          'Seats will be released. A paid booking creates a refund request; money is not transferred automatically.',
        ) ||
        !mounted) {
      return;
    }
    await _run(
      () async {
        await widget.service.cancelBooking(booking.id, reason);
      },
      'Booking cancelled.',
      cancelled: true,
    );
  }

  Future<void> _rejectRefund(Refund refund) async {
    final reason = await staffInput(
      context,
      'Reject refund',
      'Rejection reason',
      maxLength: 500,
    );
    if (reason == null || !mounted) return;
    if (!await staffConfirm(
          context,
          'Reject this refund?',
          'The customer will be notified with this reason. No money will be refunded; their active booking stays valid.',
        ) ||
        !mounted) {
      return;
    }
    await _run(() async {
      await widget.service.rejectRefund(refund.id, reason);
    }, 'Refund rejected.');
  }

  Future<void> _completeRefund(Refund refund) async {
    final ref = await staffInput(
      context,
      'Complete refund',
      'Bank transaction reference',
      maxLength: 100,
    );
    if (ref == null || !mounted) return;
    if (!await staffConfirm(
          context,
          'Transfer completed?',
          'Confirm only after transferring ${formatVnd(refund.amount)} back to the customer. This action records the transfer and sends a notification; it does not transfer money.',
        ) ||
        !mounted) {
      return;
    }
    await _run(() async {
      await widget.service.completeRefund(refund.id, ref, null);
    }, 'Refund recorded as completed.');
  }

  // Changes a seat on the map without reloading the page. A sweetbox changes
  // together with its pair, so the map is read again.
  Future<void> _setSeatType(Seat seat, String type) async {
    if (_busy || seat.type.toUpperCase() == type) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.setSeatType(seat.id, type);
      final seats = await widget.service.seats(widget.id);
      if (!mounted) return;
      final before = {for (final s in _seats) s.id: s.type};
      final changed = [
        for (final s in seats)
          if (before[s.id] != null && before[s.id] != s.type) s.label,
      ];
      _showSeats(seats);
      final labels = changed.isEmpty ? [seat.label] : changed;
      _notice(
        '${labels.join(' and ')} ${labels.length > 1 ? 'are' : 'is'} now '
        '${seatTypeLabel(type)}.',
      );
    } on Object catch (error) {
      if (mounted) _notice(staffError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeSeatCount(Room room) async {
    final before = _seats.length;
    setState(() => _busy = true);
    final seats = await showDialog<List<Seat>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SeatCountDialog(
        service: widget.service,
        roomId: room.id,
        seats: _seats,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (seats == null) return;
    _showSeats(seats);
    final change = seats.length - before;
    _notice(
      '${room.name} now has ${seats.length} seats '
      '(${change > 0 ? '+' : '-'}${change.abs()}).',
    );
    // The room's own seat count comes with the next refresh.
    await _refreshRoom();
  }

  Future<void> _generate(Room room) async {
    if (_seats.isNotEmpty) {
      setState(() => _error = 'Generate a layout only for an empty room.');
      return;
    }
    final rows = await staffInput(
      context,
      'Generate seats',
      'Number of rows',
      maxLength: 3,
    );
    if (rows == null || !mounted) return;
    final perRow = await staffInput(
      context,
      'Generate seats',
      'Seats per row',
      maxLength: 3,
    );
    if (perRow == null || !mounted) return;
    final r = int.tryParse(rows);
    final c = int.tryParse(perRow);
    if (r == null || c == null || r < 1 || c < 1 || r > 26 || c > 100) {
      setState(() => _error = 'Use 1–26 rows and 1–100 seats per row.');
      return;
    }
    if (!await staffConfirm(
          context,
          'Generate seat layout?',
          'Create ${r * c} NORMAL seats in ${room.name}. The backend blocks this for rooms with showtimes.',
        ) ||
        !mounted) {
      return;
    }
    await _run(() async {
      await widget.service.generateSeats(room.id, r, c);
    }, 'Seat layout generated.');
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: switch (widget.kind) {
      'bookings' => 'Booking details',
      'payments' => 'Payment details',
      'refunds' => 'Refund details',
      _ => 'Record details',
    },
    section: AdminSection.operations,
    child: _loading
        ? const LoadingState(message: 'Loading record...')
        : _item == null
        ? ErrorState(
            title: 'Unable to load record',
            message: _error ?? 'Please try again.',
            onRetry: _load,
          )
        : RefreshIndicator(
            onRefresh: _busy ? () async {} : _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: staffPadding(context),
              children: [
                CinemaPanel(
                  surfaceOpacity: 0.8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _details(_item!),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ..._actions(_item!),
                if (_error != null)
                  Text(
                    _error!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),
  );
  List<Widget> _details(Object item) {
    if (item is Booking) return _bookingDetails(item);
    if (item is PaymentInfo) return _paymentDetails(item);
    if (item is Refund) return _refundDetails(item);
    final rows = switch (item) {
      Showtime s => [
        ('Showtime', '#${s.id}'),
        ('Movie', '#${s.movieId}'),
        ('Room', s.roomLabel),
        ('Start', formatDateTime(s.startTime)),
        ('End', formatDateTime(s.endTime)),
        ('Price', formatVnd(s.price)),
        ('Status', s.status),
      ],
      Room r => [
        ('Room', r.name),
        ('Seats', '${_seats.isEmpty ? r.totalSeats : _seats.length}'),
      ],
      _ => <(String, String)>[],
    };
    return [
      for (final (label, value) in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.xs),
              SelectableText(value, style: AppTextStyles.body),
            ],
          ),
        ),
    ];
  }

  List<Widget> _refundDetails(Refund refund) => [
    const Text('Refund amount', style: AppTextStyles.bodySmall),
    const SizedBox(height: AppSpacing.xs),
    Text(
      formatVnd(refund.amount),
      style: AppTextStyles.heading1.copyWith(color: AppColors.primary),
    ),
    const SizedBox(height: AppSpacing.md),
    Align(
      alignment: Alignment.centerLeft,
      child: StatusBadge(
        label: refund.isCompleted
            ? 'Completed'
            : refund.isRejected
            ? 'Rejected'
            : 'Awaiting transfer',
        variant: refund.isCompleted
            ? StatusBadgeVariant.success
            : refund.isRejected
            ? StatusBadgeVariant.error
            : StatusBadgeVariant.warning,
      ),
    ),
    const SizedBox(height: AppSpacing.md),
    SelectableText(refund.refundCode, style: AppTextStyles.bodySmall),
    const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Divider(height: 1, color: AppColors.border),
    ),
    _detailField(
      Icons.local_activity_outlined,
      'Booking',
      '#${refund.bookingId ?? '—'}',
    ),
    _detailField(
      Icons.notes_outlined,
      'Request reason',
      refund.reason ?? 'Not provided',
    ),
    const SizedBox(height: AppSpacing.sm),
    const Text('Recipient bank account', style: AppTextStyles.title),
    const SizedBox(height: AppSpacing.lg),
    _detailField(
      Icons.account_balance_outlined,
      'Bank',
      refund.payerBankName ?? 'Not provided',
    ),
    _detailField(
      Icons.credit_card_outlined,
      'Account number',
      refund.payerAccountNumber ?? 'Not provided',
    ),
    _detailField(
      Icons.person_outline,
      'Account holder',
      refund.payerAccountName ?? 'Not provided',
    ),
    if (refund.isPending &&
        (refund.payerAccountNumber == null || refund.payerAccountName == null))
      const Text(
        'Contact the customer to confirm their bank details before transferring money.',
        style: AppTextStyles.bodySmall,
      ),
    const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Divider(height: 1, color: AppColors.border),
    ),
    _detailField(
      Icons.schedule_outlined,
      'Requested',
      formatDateTime(refund.createdAt),
    ),
    if (refund.processedAt != null)
      _detailField(
        Icons.history_outlined,
        'Processed',
        formatDateTime(refund.processedAt!),
      ),
    if (refund.transactionRef != null)
      _detailField(
        Icons.receipt_long_outlined,
        'Transfer reference',
        refund.transactionRef!,
      ),
    if (refund.note != null)
      _detailField(
        Icons.info_outline,
        refund.isRejected ? 'Rejection reason' : 'Processing note',
        refund.note!,
      ),
  ];

  List<Widget> _bookingDetails(Booking booking) {
    final (status, variant) = switch (booking.status) {
      BookingStatus.confirmed => ('Confirmed', StatusBadgeVariant.success),
      BookingStatus.refundPending => (
        'Refund pending',
        StatusBadgeVariant.warning,
      ),
      BookingStatus.pending => ('Awaiting payment', StatusBadgeVariant.warning),
      BookingStatus.cancelled => ('Cancelled', StatusBadgeVariant.error),
      BookingStatus.expired => ('Expired', StatusBadgeVariant.neutral),
    };
    return [
      Text(
        booking.movieTitle ?? 'Movie not provided',
        style: AppTextStyles.heading2,
      ),
      const SizedBox(height: AppSpacing.sm),
      Align(
        alignment: Alignment.centerLeft,
        child: StatusBadge(label: status, variant: variant),
      ),
      const SizedBox(height: AppSpacing.md),
      SelectableText(
        'Booking: ${booking.bookingCode}',
        style: AppTextStyles.bodySmall,
      ),
      const Divider(height: AppSpacing.xl, color: AppColors.border),
      _detailField(
        Icons.schedule_outlined,
        'Showtime',
        booking.showTime == null
            ? '#${booking.showtimeId}'
            : formatDateTime(booking.showTime!),
      ),
      _detailField(
        Icons.event_seat_outlined,
        'Seats (${booking.seats.length})',
        booking.seatLabels.isEmpty ? 'Not provided' : booking.seatLabels,
      ),
      _detailField(
        Icons.person_outline,
        'Customer #${booking.userId}',
        booking.customerEmail ?? 'No email',
      ),
      const Divider(height: AppSpacing.lg, color: AppColors.border),
      const Text('Total amount', style: AppTextStyles.bodySmall),
      const SizedBox(height: AppSpacing.xs),
      Text(
        formatVnd(booking.totalAmount),
        style: AppTextStyles.heading1.copyWith(color: AppColors.primary),
      ),
    ];
  }

  List<Widget> _paymentDetails(PaymentInfo payment) {
    final (label, variant) = switch (payment.status) {
      PaymentStatus.success => ('Paid', StatusBadgeVariant.success),
      PaymentStatus.pending => ('Awaiting payment', StatusBadgeVariant.warning),
      PaymentStatus.failed => ('Failed', StatusBadgeVariant.error),
      PaymentStatus.refundPending => (
        'Refund pending',
        StatusBadgeVariant.warning,
      ),
      PaymentStatus.refunded => ('Refunded', StatusBadgeVariant.neutral),
      PaymentStatus.unknown => ('Unknown status', StatusBadgeVariant.neutral),
    };
    return [
      const Text('Amount', style: AppTextStyles.bodySmall),
      Text(
        formatVnd(payment.amount),
        style: AppTextStyles.heading1.copyWith(color: AppColors.primary),
      ),
      const SizedBox(height: AppSpacing.sm),
      Align(
        alignment: Alignment.centerLeft,
        child: StatusBadge(label: label, variant: variant),
      ),
      const SizedBox(height: AppSpacing.md),
      SelectableText(
        'Payment: ${payment.paymentCode}',
        style: AppTextStyles.bodySmall,
      ),
      const Divider(height: AppSpacing.xl, color: AppColors.border),
      _detailField(
        Icons.confirmation_number_outlined,
        'Booking',
        '#${payment.bookingId}',
      ),
      _detailField(
        Icons.credit_card_outlined,
        'Payment method',
        payment.method ?? 'Not provided',
      ),
      _detailField(
        Icons.schedule_outlined,
        'Created',
        formatDateTime(payment.createdAt),
      ),
      if (payment.transactionRef != null)
        _detailField(
          Icons.receipt_long_outlined,
          'Transaction reference',
          payment.transactionRef!,
        ),
      if (payment.status == PaymentStatus.success)
        const Text(
          'Customers request refunds from their booking details. Staff process requests in Operations → Refunds.',
          style: AppTextStyles.bodySmall,
        ),
    ];
  }

  Future<void> _openRefund(PaymentInfo payment) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final refund = await widget.service.refundOfPayment(payment.id);
      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        AppRoutes.staffRecord('refunds', refund.id),
      );
      if (mounted) await _load();
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _detailField(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              SelectableText(value, style: AppTextStyles.body),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _button(
    String label,
    VoidCallback action, {
    bool danger = false,
    bool secondary = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: danger
        ? AppButton.danger(label: label, onPressed: _busy ? null : action)
        : secondary
        ? AppButton.secondary(label: label, onPressed: _busy ? null : action)
        : AppButton(
            label: label,
            useGradient: true,
            onPressed: _busy ? null : action,
          ),
  );
  List<Widget> _actions(Object item) => switch (item) {
    Booking b => [
      if (b.isAwaitingPayment() && b.paymentId == null)
        _button('Confirm at counter', () async {
          if (!await staffConfirm(
                context,
                'Confirm booking?',
                'Confirm only after collecting payment at the counter. This confirms the ticket; it does not charge the customer automatically.',
              ) ||
              !mounted) {
            return;
          }
          _run(() async {
            await widget.service.confirmBooking(b.id);
          }, 'Booking confirmed.');
        }),
      _button(
        'Send customer notification',
        () => Navigator.pushNamed(context, AppRoutes.staffNotify(b.id)),
        secondary: true,
      ),
      for (final payment in _payments)
        _button(
          'View payment',
          () => Navigator.pushNamed(
            context,
            AppRoutes.staffRecord('payments', payment.id),
          ),
          secondary: true,
        ),
      if (b.status == BookingStatus.pending ||
          b.status == BookingStatus.confirmed)
        _button('Cancel booking', () => _cancelBooking(b), danger: true),
    ],
    Showtime s => [
      if (s.status != 'CANCELLED')
        _button('Edit showtime', () async {
          await Navigator.pushNamed(context, AppRoutes.staffEditShowtime(s.id));
          if (mounted) _load();
        }),
      if (s.status != 'CANCELLED')
        _button(s.isOpen ? 'Close sales' : 'Open sales', () async {
          if (!await staffConfirm(
                context,
                'Change sales status?',
                '${s.isOpen ? 'Close' : 'Open'} booking for this showtime?',
              ) ||
              !mounted) {
            return;
          }
          _run(() async {
            await widget.service.setShowtimeStatus(
              s.id,
              s.isOpen ? 'CLOSED' : 'OPEN',
            );
          }, 'Sales status updated.');
        }),
      if (s.status != 'CANCELLED')
        _button('Cancel showtime', () async {
          if (!await staffConfirm(
                context,
                'Cancel showtime?',
                'This stops sales for the showtime. Review existing bookings and refunds separately.',
              ) ||
              !mounted) {
            return;
          }
          _run(
            () async {
              await widget.service.cancelShowtime(s.id);
            },
            'Showtime cancelled.',
            cancelled: true,
          );
        }, danger: true),
    ],
    Room r => [
      if (_seats.isEmpty)
        _button('Generate seat layout', () => _generate(r))
      else if (isAdminAccount(SessionProvider.of(context).user?.roles))
        _button('Change seat count', () => _changeSeatCount(r)),
      _LiveStatus(updatedAt: _updatedAt, failed: _liveFailed),
      const SizedBox(height: AppSpacing.md),
      if (_seats.isNotEmpty) ...[
        CinemaPanel(
          surfaceOpacity: 0.8,
          child: RoomSeatMap(
            seats: _seats,
            highlighted: _newSeatIds,
            onTypeSelected: _busy ? null : _setSeatType,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      const Text(
        'Tap a seat to change its type. Seat changes are blocked for rooms '
        'with existing showtimes.',
        style: AppTextStyles.caption,
      ),
      const SizedBox(height: AppSpacing.md),
    ],
    PaymentInfo p => [
      _button(
        'View booking',
        () => Navigator.pushNamed(
          context,
          AppRoutes.staffRecord('bookings', p.bookingId),
        ),
        secondary: true,
      ),
      if (p.method?.toUpperCase() == 'PAYOS' &&
          p.status == PaymentStatus.pending)
        _button(
          'Verify with PayOS',
          () => _run(() async {
            final booking = await widget.service.booking(p.bookingId);
            if (!mounted) return;
            final email = await staffInput(
              context,
              'Ticket recipient',
              'Customer email',
              initial: booking.customerEmail ?? '',
              maxLength: 150,
              email: true,
            );
            if (email == null) throw const _StaffActionCancelled();
            final payment = await widget.service.processPayment(p.id, email);
            if (payment.status != PaymentStatus.success) {
              throw const FormatException('Payment has not succeeded.');
            }
          }, 'Payment verified.'),
        ),
      if (p.status == PaymentStatus.refundPending ||
          p.status == PaymentStatus.refunded)
        _button('View refund request', () => _openRefund(p), secondary: true),
    ],
    Refund r => [
      if (r.isPending)
        _button('Record completed transfer', () => _completeRefund(r)),
      if (r.isPending)
        _button('Reject refund', () => _rejectRefund(r), danger: true),
      if (r.bookingId != null)
        _button(
          'View booking',
          () => Navigator.pushNamed(
            context,
            AppRoutes.staffRecord('bookings', r.bookingId!),
          ),
          secondary: true,
        ),
    ],
    _ => [],
  };
}

class _LiveStatus extends StatelessWidget {
  const _LiveStatus({required this.updatedAt, required this.failed});

  final DateTime? updatedAt;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final at = updatedAt;
    final text = failed
        ? 'Cannot reach the server. Retrying...'
        : at == null
        ? 'Live'
        : 'Live • updated ${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
    return Row(
      key: const Key('roomLiveStatus'),
      children: [
        Icon(
          Icons.circle,
          size: 10,
          color: failed ? AppColors.warning : AppColors.success,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(text, style: AppTextStyles.caption)),
      ],
    );
  }
}

class _StaffActionCancelled implements Exception {
  const _StaffActionCancelled();
}
