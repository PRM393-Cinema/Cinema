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
import '../../../core/utils/layout.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/booking_repository.dart';
import '../payment_args.dart';
import '../../booking/widgets/booking_cancellation_dialog.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    required this.bookingRepository,
    this.bookingId,
    super.key,
  });

  final BookingRepository bookingRepository;

  // Set when the screen is opened from its URL: the booking is loaded by id.
  final int? bookingId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  // Picks up confirmations made by the PayOS webhook while the app is open.
  static const _pollInterval = Duration(seconds: 5);

  Booking? _booking;
  bool _bookingRequested = false;
  bool _isLoadingBooking = false;
  Timer? _countdownTimer;
  Timer? _pollTimer;
  bool _checkoutOpened = false;
  bool _hasPayOsPayment = false;
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
      _start(args);
    } else if (_booking == null &&
        !_bookingRequested &&
        widget.bookingId != null) {
      _bookingRequested = true;
      _isLoadingBooking = true;
      _loadBooking(widget.bookingId!);
    }
  }

  void _start(Booking booking) {
    _booking = booking;
    _hasPayOsPayment = booking.paymentId != null;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollBooking());
  }

  // Opened from its URL (web refresh): load the booking first. A booking that
  // is no longer waiting for payment goes straight to its result.
  Future<void> _loadBooking(int bookingId) async {
    try {
      final booking = await widget.bookingRepository.getBooking(bookingId);
      if (!mounted) return;
      if (booking.status != BookingStatus.pending) {
        _openResult(booking.id);
        return;
      }
      setState(() {
        _isLoadingBooking = false;
        _start(booking);
      });
    } on Object {
      // Shown as "Booking not found" with a link to My Bookings.
      if (mounted) setState(() => _isLoadingBooking = false);
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
    if (booking == null ||
        _hasLeft ||
        _isVerifying ||
        _isCancelling ||
        _isStartingCheckout) {
      return;
    }

    try {
      final latest = await widget.bookingRepository.getBooking(booking.id);
      if (!mounted || _hasLeft || _isCancelling || _isStartingCheckout) return;

      if (latest.status != BookingStatus.pending) {
        _openResult(latest.id);
        return;
      }
      setState(() {
        _booking = latest;
        _hasPayOsPayment = _hasPayOsPayment || latest.paymentId != null;
      });
      if (_hasPayOsPayment) {
        await _verifyPayment(quietWhenPending: true);
      }
    } on ApiException {
      // Temporary network problems: try again on the next tick.
    } on Object {
      // Same as above.
    }
  }

  Future<void> _startCheckout(Booking booking) async {
    if (_isStartingCheckout || _isVerifying || _isCancelling || _hasLeft) {
      return;
    }
    setState(() {
      _isStartingCheckout = true;
      _message = null;
    });

    try {
      final checkout = await widget.bookingRepository.startPayOsCheckout(
        booking,
      );
      if (!mounted || _hasLeft) return;
      setState(() => _hasPayOsPayment = true);
      final checkoutUrl = checkout.checkoutUrl;

      if (checkoutUrl == null) {
        // A completed or cancelled link goes to verification instead.
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
          _hasPayOsPayment = true;
          _isVerifying = false;
          if (!quietWhenPending) {
            _messageIsError = false;
            _message = 'Payment is still pending. Tap "Continue with PayOS" below to reopen your payment page.';
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
      builder: (_) => const BookingCancellationDialog(
        message: 'Your seats will be released for other customers.',
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
      await showBookingCancellationNotice(
        context,
        message: 'Your seats have been released.',
      );
      if (!mounted) return;
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
      AppRoutes.paymentResult(bookingId),
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

    if (booking == null && _isLoadingBooking) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Payment'),
        ),
        body: const LoadingState(message: 'Loading booking...'),
      );
    }

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Payment'),
        ),
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
      body: CinemaBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: centeredPadding(context, AppSpacing.lg),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Payment', style: AppTextStyles.heading2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HoldTimer(
                            remaining: remaining,
                            expired: holdExpired,
                          ),
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
              Padding(
                padding: centeredPadding(
                  context,
                  AppSpacing.lg,
                ).copyWith(top: AppSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: _hasPayOsPayment
                          ? 'Continue with PayOS'
                          : 'Pay with PayOS',
                      useGradient: true,
                      leadingIcon: Icons.qr_code_2_outlined,
                      isLoading: _isStartingCheckout,
                      onPressed: holdExpired || isBusy
                          ? null
                          : () => _startCheckout(booking),
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
        const Text('How to pay', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.sm),
        for (final (index, step) in _steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    '${index + 1}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
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
        : (isUrgent ? AppColors.warning : AppColors.primary);

    final text = expired
        ? 'Your seat hold has expired. Please book again.'
        : remaining == null
        ? 'Your seats are held while you pay.'
        : 'Seats held for ${formatCountdown(remaining!)}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

    return CinemaPanel(
      surfaceOpacity: 0.8,
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
          Text('Seats: ${booking.seatLabels}', style: AppTextStyles.bodySmall),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1, color: AppColors.border),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: AppTextStyles.heading2),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  formatVnd(booking.totalAmount),
                  textAlign: TextAlign.end,
                  style: AppTextStyles.heading2.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
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
