import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/payment.dart';
import '../../../data/services/staff_service.dart';
import '../../admin/widgets/admin_page.dart';
import '../../booking/widgets/ticket_qr_card.dart';
import '../widgets/staff_feedback.dart';
import '../widgets/ticket_print.dart';

enum CounterPayMethod { cash, transfer }

// Taking the money for a booking at the counter: cash (the screen works out
// the change) or a bank transfer the customer pays by scanning the PayOS QR
// code. Either way a payment is recorded and the ticket confirmed; its QR code
// is then emailed, printed or shown on screen, and a customer whose show is
// about to start can be checked in straight away.
class StaffCounterCheckoutScreen extends StatefulWidget {
  const StaffCounterCheckoutScreen({
    required this.service,
    required this.bookingId,
    this.transferCheckEvery = const Duration(seconds: 3),
    super.key,
  });

  final StaffService service;
  final int bookingId;

  // How often the screen asks whether the bank transfer arrived.
  final Duration transferCheckEvery;

  @override
  State<StaffCounterCheckoutScreen> createState() =>
      _StaffCounterCheckoutScreenState();
}

class _StaffCounterCheckoutScreenState
    extends State<StaffCounterCheckoutScreen> {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _received = TextEditingController();
  final _email = TextEditingController();
  Booking? _booking;
  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  String? _error;
  CounterPayMethod _method = CounterPayMethod.cash;
  PayOsCheckout? _transfer;
  Timer? _transferTimer;
  bool _checkingTransfer = false;
  Timer? _clock;

  // Change handed back for the cash just taken.
  double? _change;

  @override
  void initState() {
    super.initState();
    _load();
    // Counts the seat hold down.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _booking?.status == BookingStatus.pending) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _transferTimer?.cancel();
    _received.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final booking = await widget.service.booking(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _loadError = null;
        if (_email.text.isEmpty) _email.text = booking.customerEmail ?? '';
      });
    } on Object catch (error) {
      if (mounted) setState(() => _loadError = staffError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // The email the ticket goes to; none when the field is empty.
  String? get _recipient {
    final email = _email.text.trim();
    return email.isEmpty ? null : email;
  }

  String? get _emailError {
    final email = _recipient;
    return email == null ||
            (_emailPattern.hasMatch(email) && email.length <= 150)
        ? null
        : 'Enter a valid email, or leave it empty.';
  }

  double get _cashReceived =>
      double.tryParse(_received.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payCash(Booking booking) async {
    final emailError = _emailError;
    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }
    final received = _cashReceived;
    final change = received - booking.totalAmount;
    if (change < 0) return;
    if (!await staffConfirm(
          context,
          'Take ${formatVnd(received)} in cash?',
          change > 0
              ? 'Give back ${formatVnd(change)} in change. The ticket is '
                    'confirmed straight away.'
              : 'The customer paid the exact amount. The ticket is confirmed '
                    'straight away.',
        ) ||
        !mounted) {
      return;
    }
    await _act(() async {
      await widget.service.payCash(booking.id, received, email: _recipient);
      _stopTransferChecks();
      _change = change;
      await _load();
    });
  }

  Future<void> _showTransfer(Booking booking) async {
    final emailError = _emailError;
    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }
    await _act(() async {
      final transfer = await widget.service.counterTransfer(booking);
      if (!mounted) return;
      setState(() => _transfer = transfer);
      _transferTimer?.cancel();
      _transferTimer = Timer.periodic(
        widget.transferCheckEvery,
        (_) => _checkTransfer(),
      );
    });
  }

  void _stopTransferChecks() {
    _transferTimer?.cancel();
    _transferTimer = null;
  }

  // PayOS confirms the ticket as soon as the money arrives; [byHand] reports
  // a transfer that has not arrived yet.
  Future<void> _checkTransfer({bool byHand = false}) async {
    final transfer = _transfer;
    if (transfer == null || _checkingTransfer) return;
    _checkingTransfer = true;
    if (byHand) setState(() => _error = null);
    try {
      final email = _emailError == null ? _recipient : null;
      final payment = await widget.service.verifyTransfer(
        transfer.orderCode,
        email: email,
      );
      if (!mounted) return;
      switch (payment.status) {
        case PaymentStatus.success:
          _stopTransferChecks();
          await _load();
        case PaymentStatus.failed:
          _stopTransferChecks();
          setState(() {
            _transfer = null;
            _error =
                'The bank transfer was cancelled or has expired. Show a new '
                'QR code or take cash.';
          });
          await _load();
        case _:
          if (byHand) {
            setState(() => _error = 'The transfer has not arrived yet.');
          }
      }
    } on Object catch (error) {
      if (byHand && mounted) setState(() => _error = staffError(error));
    } finally {
      _checkingTransfer = false;
    }
  }

  Future<void> _checkIn(Booking booking) => _act(() async {
    await widget.service.checkIn(booking.id);
    await _load();
  });

  Future<void> _print(Booking booking) => _act(() => printTicket(booking));

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    return AdminPage(
      title: booking?.status == BookingStatus.confirmed
          ? 'Ticket'
          : 'Take payment',
      section: AdminSection.operations,
      child: _loading
          ? const LoadingState(message: 'Loading booking...')
          : booking == null
          ? ErrorState(
              title: 'Unable to load',
              message: _loadError ?? 'Booking not found.',
              onRetry: () {
                setState(() => _loading = true);
                _load();
              },
            )
          : SingleChildScrollView(
              padding: staffPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BookingSummary(booking: booking),
                  const SizedBox(height: AppSpacing.lg),
                  ...switch (booking.status) {
                    BookingStatus.confirmed => _paid(booking),
                    BookingStatus.pending when !booking.isHoldExpired() =>
                      _payment(booking),
                    _ => _closed(booking),
                  },
                  if (_busy) ...[
                    const SizedBox(height: AppSpacing.md),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        _error!,
                        key: const Key('checkoutError'),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  List<Widget> _payment(Booking booking) {
    final remaining = booking.expiresAt?.difference(DateTime.now());
    return [
      if (remaining != null)
        Text(
          'Seats held for ${formatCountdown(remaining)}',
          key: const Key('holdCountdown'),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
        ),
      const SizedBox(height: AppSpacing.md),
      AppTextField(
        label: 'Email the ticket to (optional)',
        controller: _email,
        enabled: !_busy,
        keyboardType: TextInputType.emailAddress,
        onChanged: (_) => setState(() => _error = null),
      ),
      const SizedBox(height: AppSpacing.lg),
      SegmentedButton<CounterPayMethod>(
        segments: const [
          ButtonSegment(
            value: CounterPayMethod.cash,
            label: Text('Cash'),
            icon: Icon(Icons.payments_outlined),
          ),
          ButtonSegment(
            value: CounterPayMethod.transfer,
            label: Text('Bank transfer'),
            icon: Icon(Icons.qr_code_2_rounded),
          ),
        ],
        selected: {_method},
        onSelectionChanged: _busy
            ? null
            : (selection) => setState(() {
                _method = selection.single;
                _error = null;
              }),
      ),
      const SizedBox(height: AppSpacing.lg),
      CinemaPanel(
        surfaceOpacity: 0.8,
        child: switch (_method) {
          CounterPayMethod.cash => _cashPanel(booking),
          CounterPayMethod.transfer => _transferPanel(booking),
        },
      ),
    ];
  }

  Widget _cashPanel(Booking booking) {
    final received = _cashReceived;
    final change = received - booking.totalAmount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          key: const Key('cashReceived'),
          label: 'Cash received (₫)',
          controller: _received,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final amount in cashSuggestions(booking.totalAmount))
              ActionChip(
                key: ValueKey('cashSuggestion-${amount.round()}'),
                label: Text(formatVnd(amount)),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _received.text = amount.round().toString();
                        _error = null;
                      }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (received > 0)
          Text(
            change >= 0
                ? 'Change: ${formatVnd(change)}'
                : 'Short by ${formatVnd(-change)}',
            key: const Key('cashChange'),
            style: AppTextStyles.heading2.copyWith(
              color: change >= 0 ? AppColors.success : AppColors.error,
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Confirm cash payment',
          useGradient: true,
          isLoading: _busy,
          onPressed: _busy || received <= 0 || change < 0
              ? null
              : () => _payCash(booking),
        ),
      ],
    );
  }

  Widget _transferPanel(Booking booking) {
    final transfer = _transfer;
    if (transfer == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Show a PayOS QR code the customer scans with their banking app. '
            'The ticket is confirmed as soon as the money arrives.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Show transfer QR',
            useGradient: true,
            leadingIcon: Icons.qr_code_2_rounded,
            isLoading: _busy,
            onPressed: _busy ? null : () => _showTransfer(booking),
          ),
        ],
      );
    }

    final bankQr = transfer.qrCode;
    final data = bankQr ?? transfer.checkoutUrl;
    return Column(
      children: [
        if (data != null)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: QrImageView(
                key: const Key('transferQr'),
                data: data,
                size: 240,
                backgroundColor: Colors.white,
                semanticsLabel: 'Bank transfer QR code',
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          formatVnd(booking.totalAmount),
          style: AppTextStyles.heading2.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          bankQr != null
              ? 'Scan with any banking app. The amount and the transfer note '
                    'are filled in.'
              : 'Scan with the phone camera to open the PayOS payment page, '
                    'then pay with a banking app.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.sm),
            Text('Waiting for the transfer…', style: AppTextStyles.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton.secondary(
            label: 'Check payment',
            onPressed: _busy ? null : () => _checkTransfer(byHand: true),
          ),
        ),
      ],
    );
  }

  List<Widget> _paid(Booking booking) {
    final change = _change;
    final showTime = booking.showTime;
    // Check-in opens a while before the show (backend CheckIn:OpensBeforeMinutes).
    final showStartsSoon =
        showTime == null ||
        showTime.difference(DateTime.now()) <= Booking.checkInOpensBefore;
    return [
      CinemaPanel(
        surfaceOpacity: 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  booking.isCheckedIn ? 'Paid and checked in' : 'Paid',
                  style: AppTextStyles.heading2,
                ),
              ],
            ),
            if (change != null && change > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Give back ${formatVnd(change)} in change.',
                key: const Key('changeToGive'),
                style: AppTextStyles.title.copyWith(color: AppColors.success),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              booking.customerEmail != null
                  ? 'The ticket with its QR code is emailed to '
                        '${booking.customerEmail}.'
                  : 'No email: print the ticket or let the customer take a '
                        'photo of the QR code.',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      TicketQrCard(booking: booking),
      const SizedBox(height: AppSpacing.lg),
      if (booking.canCheckIn && showStartsSoon) ...[
        AppButton(
          label: 'Check in now',
          useGradient: true,
          leadingIcon: Icons.how_to_reg_outlined,
          isLoading: _busy,
          onPressed: _busy ? null : () => _checkIn(booking),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (canPrintTicket) ...[
        AppButton.secondary(
          label: 'Print ticket',
          leadingIcon: Icons.print_outlined,
          onPressed: _busy ? null : () => _print(booking),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      AppButton.secondary(
        label: 'Sell another ticket',
        onPressed: () => Navigator.pushReplacementNamed(
          context,
          AppRoutes.staffCreateBooking,
        ),
      ),
    ];
  }

  List<Widget> _closed(Booking booking) => [
    CinemaPanel(
      surfaceOpacity: 0.8,
      child: Text(switch (booking.status) {
        BookingStatus.pending || BookingStatus.expired =>
          'The seat hold expired before payment. Start a new booking.',
        BookingStatus.cancelled => 'This booking was cancelled.',
        _ => 'This booking is waiting for a refund and cannot be paid.',
      }, style: AppTextStyles.body),
    ),
    const SizedBox(height: AppSpacing.lg),
    AppButton.secondary(
      label: 'View booking',
      onPressed: () => Navigator.pushReplacementNamed(
        context,
        AppRoutes.staffRecord('bookings', booking.id),
      ),
    ),
    const SizedBox(height: AppSpacing.sm),
    AppButton.secondary(
      label: 'Sell another ticket',
      onPressed: () =>
          Navigator.pushReplacementNamed(context, AppRoutes.staffCreateBooking),
    ),
  ];
}

// Quick amounts for the cash a customer hands over: the exact total and the
// total rounded up to the notes people usually pay with.
List<double> cashSuggestions(double total) {
  final amounts = <double>{total};
  for (final note in const [50000, 100000, 500000]) {
    amounts.add(((total / note).ceil() * note).toDouble());
  }
  return amounts.toList()..sort();
}

class _BookingSummary extends StatelessWidget {
  const _BookingSummary({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final (label, variant) = switch (booking.status) {
      BookingStatus.confirmed => ('Paid', StatusBadgeVariant.success),
      BookingStatus.pending when !booking.isHoldExpired() => (
        'Awaiting payment',
        StatusBadgeVariant.warning,
      ),
      BookingStatus.cancelled => ('Cancelled', StatusBadgeVariant.error),
      BookingStatus.refundPending => (
        'Refund pending',
        StatusBadgeVariant.warning,
      ),
      _ => ('Expired', StatusBadgeVariant.neutral),
    };
    final customer = [?booking.customerEmail, ?booking.customerPhone];
    return CinemaPanel(
      surfaceOpacity: 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.movieTitle ?? 'Booking #${booking.id}',
                  style: AppTextStyles.heading2,
                ),
              ),
              StatusBadge(label: label, variant: variant),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (booking.showTime != null)
            Text(
              formatDateTime(booking.showTime!),
              style: AppTextStyles.bodySmall,
            ),
          Text(
            'Seats ${booking.seatLabels} • ${booking.bookingCode}',
            style: AppTextStyles.bodySmall,
          ),
          if (booking.concessions.isNotEmpty)
            Text(
              'Snacks: ${booking.snacksText}',
              key: const Key('checkoutSnacks'),
              style: AppTextStyles.bodySmall,
            ),
          if (booking.hasDiscount)
            Text(
              'Discount: ${booking.discountText}',
              key: const Key('checkoutDiscount'),
              style: AppTextStyles.bodySmall,
            ),
          Text(
            [
              booking.isWalkIn
                  ? 'Walk-in guest'
                  : 'Customer #${booking.userId}',
              ...customer,
            ].join(' • '),
            style: AppTextStyles.bodySmall,
          ),
          const Divider(height: AppSpacing.xl, color: AppColors.border),
          const Text('Total', style: AppTextStyles.bodySmall),
          Text(
            formatVnd(booking.totalAmount),
            key: const Key('checkoutTotal'),
            style: AppTextStyles.heading1.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
