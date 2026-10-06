import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_state.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/booking_repository.dart';
import '../payment_args.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({required this.bookingRepository, super.key});

  final BookingRepository bookingRepository;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  // Picks up confirmations made by the PayOS webhook while the app is open.
  static const _pollInterval = Duration(seconds: 5);

  Booking? _booking;
  Timer? _countdownTimer;
  Timer? _pollTimer;
  bool _checkoutOpened = false;
  bool _isStartingCheckout = false;
  bool _isVerifying = false;
  bool _isCancelling = false;
  bool _hasLeft = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (_booking == null && args is Booking) {
      _booking = args;
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      _pollTimer = Timer.periodic(_pollInterval, (_) => _pollBooking());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the PayOS page: ask PayOS for the result.
    if (state == AppLifecycleState.resumed && _checkoutOpened) {
      _verifyPayment(quietWhenPending: true);
    }
  }

  Future<void> _pollBooking() async {
    final booking = _booking;
    if (booking == null || _hasLeft || _isVerifying || _isCancelling) return;

    try {
      final latest = await widget.bookingRepository.getBooking(booking.id);
      if (!mounted || _hasLeft) return;

      if (latest.status != BookingStatus.pending) {
        _openResult(latest.id);
        return;
      }
      setState(() => _booking = latest);
    } on ApiException {
      // Temporary network problems: try again on the next tick.
    } on Object {
      // Same as above.
    }
  }

  Future<void> _startCheckout(Booking booking) async {
    setState(() {
      _isStartingCheckout = true;
      _message = null;
    });

    try {
      final checkout = await widget.bookingRepository.startPayOsCheckout(
        booking,
      );
      final checkoutUrl = checkout.checkoutUrl;

      if (checkoutUrl == null) {
        // A payment already exists without a link: check its result instead.
        setState(() => _isStartingCheckout = false);
        await _verifyPayment();
        return;
      }

      // On web the PayOS page replaces the app and PayOS redirects back to
      // it afterwards. Elsewhere the browser opens on top of the app.
      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );
      if (!mounted) return;

      setState(() {
        _isStartingCheckout = false;
        _checkoutOpened = launched;
        _messageIsError = !launched;
        _message = launched
            ? 'Complete the payment on the PayOS page, then come back here. '
                  'Your booking is confirmed automatically once PayOS receives the money.'
            : 'Unable to open the PayOS page. Please try again.';
      });
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } on FormatException {
      _showMessage('The server returned an invalid response.', isError: true);
    } on Object {
      _showMessage(
        'Unable to open the PayOS page. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _verifyPayment({bool quietWhenPending = false}) async {
    final booking = _booking;
    if (booking == null || _isVerifying || _hasLeft) return;

    setState(() {
      _isVerifying = true;
      if (!quietWhenPending) _message = null;
    });

    try {
      final payment = await widget.bookingRepository.verifyPayOsPayment(
        booking.id,
      );
      if (!mounted) return;

      if (payment.status == PaymentStatus.pending) {
        setState(() {
          _isVerifying = false;
          if (!quietWhenPending) {
            _messageIsError = false;
            _message = 'PayOS has not received your payment yet. Finish the payment on the PayOS page and check again.';
          }
        });
        return;
      }

      setState(() => _isVerifying = false);
      _openResult(booking.id, payment: payment);
    } on ApiException catch (error) {
      if (quietWhenPending) {
        if (mounted) setState(() => _isVerifying = false);
        return;
      }
      // 404: no PayOS payment has been created for this booking yet.
      _showMessage(
        error.statusCode == 404
            ? 'Start the payment with PayOS first.'
            : error.message,
        isError: true,
      );
    } on FormatException {
      _showMessage('The server returned an invalid response.', isError: true);
    } on Object {
      _showMessage('Something went wrong. Please try again.', isError: true);
    }
  }

  Future<void> _cancelBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel booking?', style: AppTextStyles.title),
        content: const Text(
          'Your seats will be released for other customers.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Keep booking',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Cancel booking',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isCancelling = true;
      _message = null;
    });

    try {
      await widget.bookingRepository.cancelBooking(booking.id);
      if (!mounted) return;

      _hasLeft = true;
      _pollTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your booking has been cancelled.')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } on FormatException {
      _showMessage('The server returned an invalid response.', isError: true);
    } on Object {
      _showMessage('Something went wrong. Please try again.', isError: true);
    }
  }

  void _openResult(int bookingId, {PaymentInfo? payment}) {
    if (_hasLeft || !mounted) return;
    _hasLeft = true;
    _pollTimer?.cancel();

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.paymentResult,
      arguments: PaymentResultArgs(bookingId: bookingId, payment: payment),
    );
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _isStartingCheckout = false;
      _isVerifying = false;
      _isCancelling = false;
      _message = message;
      _messageIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: ErrorState(
          title: 'Booking not found',
          message:
              'Open your booking from My Bookings to continue the payment.',
          onRetry: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.myBookings),
        ),
      );
    }

    final remaining = booking.expiresAt?.difference(DateTime.now());
    final holdExpired = booking.isHoldExpired();
    final isBusy = _isStartingCheckout || _isVerifying || _isCancelling;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HoldTimer(remaining: remaining, expired: holdExpired),
                        const SizedBox(height: AppSpacing.xl),
                        _BookingCard(booking: booking),
                        if (_message != null) ...[
                          const SizedBox(height: AppSpacing.xl),
                          _MessageBanner(
                            message: _message!,
                            isError: _messageIsError,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        const _PaymentSteps(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: 'Pay with PayOS',
                    leadingIcon: Icons.qr_code_2_outlined,
                    isLoading: _isStartingCheckout,
                    onPressed: holdExpired || isBusy
                        ? null
                        : () => _startCheckout(booking),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton.secondary(
                    label: 'I have paid',
                    isLoading: _isVerifying,
                    onPressed: isBusy ? null : () => _verifyPayment(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: isBusy ? null : () => _cancelBooking(booking),
                    child: const Text(
                      'Cancel booking',
                      style: TextStyle(color: AppColors.error),
                    ),
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

class _PaymentSteps extends StatelessWidget {
  const _PaymentSteps();

  static const _steps = [
    'Tap "Pay with PayOS" to open the secure PayOS checkout.',
    'Scan the VietQR code with your banking app, or transfer manually.',
    'Your tickets are confirmed automatically once the payment arrives.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How to pay', style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.sm),
        for (final (index, step) in _steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.surfaceSoft,
                  child: Text('${index + 1}', style: AppTextStyles.caption),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(step, style: AppTextStyles.bodySmall)),
              ],
            ),
          ),
      ],
    );
  }
}

class _HoldTimer extends StatelessWidget {
  const _HoldTimer({required this.remaining, required this.expired});

  final Duration? remaining;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final isUrgent =
        expired ||
        (remaining != null && remaining! < const Duration(minutes: 2));
    final color = expired
        ? AppColors.error
        : (isUrgent ? AppColors.warning : AppColors.success);

    final text = expired
        ? 'Your seat hold has expired. Please book again.'
        : remaining == null
        ? 'Your seats are held while you pay.'
        : 'Seats held for ${formatCountdown(remaining!)}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                text,
                key: const Key('holdTimerText'),
                style: AppTextStyles.title.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final showTime = booking.showTime;

    return DecoratedBox(
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
            Text('Code: ${booking.bookingCode}', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.sm),
            Text(
              booking.movieTitle ?? 'Movie ticket',
              style: AppTextStyles.heading2,
            ),
            if (showTime != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(formatDateTime(showTime), style: AppTextStyles.body),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Seats: ${booking.seatLabels}',
              style: AppTextStyles.bodySmall,
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
                  formatVnd(booking.totalAmount),
                  style: AppTextStyles.heading2.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.textSecondary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: color,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message, style: AppTextStyles.bodySmall)),
          ],
        ),
      ),
    );
  }
}
