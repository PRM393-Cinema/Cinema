import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/payment.dart';
import '../../../data/models/room.dart';
import '../../../data/models/seat.dart';
import '../../../data/models/showtime.dart';
import '../../../data/services/staff_service.dart';
import '../../admin/widgets/admin_page.dart';
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
  Object? _item;
  List<Seat> _seats = [];
  List<PaymentInfo> _payments = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

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

  Future<void> _refundPayment(PaymentInfo payment) async {
    final reason = await staffInput(context, 'Request refund', 'Reason');
    if (reason == null || !mounted) return;
    if (!await staffConfirm(
          context,
          'Create refund request?',
          'The booking will be cancelled. Complete the bank transfer separately before marking the refund complete.',
        ) ||
        !mounted) {
      return;
    }
    await _run(() async {
      await widget.service.requestRefund(payment.id, reason);
    }, 'Refund request created.');
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

  Future<void> _editSeat(Seat seat, String type) async {
    if (!await staffConfirm(
          context,
          'Change seat type?',
          '${seat.label}: $type. The backend blocks changes when the room already has showtimes.',
        ) ||
        !mounted) {
      return;
    }
    await _run(() async {
      await widget.service.seat(seat.id);
      await widget.service.setSeatType(seat.id, type);
    }, 'Seat type updated.');
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
    title: 'Record details',
    selectedIndex: 1,
    staffMode: true,
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
    final rows = switch (item) {
      Booking b => [
        ('Booking', b.bookingCode),
        ('Movie', b.movieTitle ?? 'Not provided'),
        ('Customer', '#${b.userId} · ${b.customerEmail ?? 'No email'}'),
        ('Status', b.status.name.toUpperCase()),
        (
          'Showtime',
          b.showTime == null ? '#${b.showtimeId}' : formatDateTime(b.showTime!),
        ),
        ('Seats', b.seatLabels),
        ('Total', formatVnd(b.totalAmount)),
      ],
      Showtime s => [
        ('Showtime', '#${s.id}'),
        ('Movie', '#${s.movieId}'),
        ('Room', s.roomLabel),
        ('Start', formatDateTime(s.startTime)),
        ('End', formatDateTime(s.endTime)),
        ('Price', formatVnd(s.price)),
        ('Status', s.status),
      ],
      Room r => [('Room', r.name), ('Seats', '${r.totalSeats}')],
      PaymentInfo p => [
        ('Payment', p.paymentCode),
        ('Booking', '#${p.bookingId}'),
        ('Amount', formatVnd(p.amount)),
        ('Method', p.method ?? 'Not provided'),
        ('Status', p.status.name),
        ('Reference', p.transactionRef ?? 'Not provided'),
      ],
      Refund r => [
        ('Refund', r.refundCode),
        ('Booking', '#${r.bookingId ?? '—'}'),
        ('Amount', formatVnd(r.amount)),
        ('Status', r.status),
        ('Reason', r.reason ?? 'Not provided'),
        ('Bank', r.payerBankName ?? 'Not provided'),
        ('Account number', r.payerAccountNumber ?? 'Ask the customer'),
        ('Account holder', r.payerAccountName ?? 'Ask the customer'),
        ('Transaction', r.transactionRef ?? 'Not recorded'),
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

  Widget _button(String label, VoidCallback action, {bool danger = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: danger
            ? AppButton.danger(label: label, onPressed: _busy ? null : action)
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
      if (b.status == BookingStatus.pending ||
          b.status == BookingStatus.confirmed)
        _button('Cancel booking', () => _cancelBooking(b), danger: true),
      _button(
        'Send customer notification',
        () => Navigator.pushNamed(context, AppRoutes.staffNotify(b.id)),
      ),
      for (final payment in _payments)
        _button(
          'View payment',
          () => Navigator.pushNamed(
            context,
            AppRoutes.staffRecord('payments', payment.id),
          ),
        ),
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
      if (_seats.isEmpty) _button('Generate seat layout', () => _generate(r)),
      const Text(
        'Seat changes are blocked for rooms with existing showtimes.',
        style: AppTextStyles.caption,
      ),
      const SizedBox(height: AppSpacing.md),
      for (final seat in _seats)
        ListTile(
          title: Text(seat.label, style: AppTextStyles.body),
          subtitle: Text(seat.type, style: AppTextStyles.caption),
          trailing: PopupMenuButton<String>(
            enabled: !_busy,
            tooltip: 'Change seat type',
            onSelected: (type) => _editSeat(seat, type),
            itemBuilder: (_) => [
              for (final type in ['NORMAL', 'VIP'])
                PopupMenuItem(value: type, child: Text(type)),
            ],
          ),
        ),
    ],
    PaymentInfo p => [
      _button(
        'View booking',
        () => Navigator.pushNamed(
          context,
          AppRoutes.staffRecord('bookings', p.bookingId),
        ),
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
      if (p.status == PaymentStatus.success)
        _button('Request refund', () => _refundPayment(p), danger: true),
    ],
    Refund r => [
      if (!r.isCompleted)
        _button('Record completed transfer', () => _completeRefund(r)),
      if (r.bookingId != null)
        _button(
          'View booking',
          () => Navigator.pushNamed(
            context,
            AppRoutes.staffRecord('bookings', r.bookingId!),
          ),
        ),
    ],
    _ => [],
  };
}

class _StaffActionCancelled implements Exception {
  const _StaffActionCancelled();
}
