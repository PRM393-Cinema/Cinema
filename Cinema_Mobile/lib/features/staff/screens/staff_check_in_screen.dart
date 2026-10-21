import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/cinema_page.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/showtime.dart';
import '../../../data/services/staff_service.dart';
import '../../admin/widgets/admin_page.dart';
import '../../booking/screens/my_bookings_screen.dart';
import '../widgets/staff_feedback.dart';

// Opens the camera and returns the first QR code it reads, or null when the
// staff member closes it.
typedef TicketScanner = Future<String?> Function(BuildContext context);

// Phones, tablets, Macs and browsers have a camera plugin; Windows and Linux
// builds type the code (or use a handheld scanner, which types it too).
bool get cameraScanSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

// Check-in on the admin website.
class StaffCheckInScreen extends StatelessWidget {
  const StaffCheckInScreen({required this.service, this.scanner, super.key});

  final StaffService service;
  final TicketScanner? scanner;

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Ticket check-in',
    section: AdminSection.checkIn,
    child: SingleChildScrollView(
      padding: staffPadding(context),
      child: CheckInPanel(service: service, scanner: scanner),
    ),
  );
}

// Check-in in the app, for staff at the cinema entrance with a phone.
class MobileCheckInScreen extends StatelessWidget {
  const MobileCheckInScreen({required this.service, this.scanner, super.key});

  final StaffService service;
  final TicketScanner? scanner;

  @override
  Widget build(BuildContext context) => CinemaPage(
    title: 'Ticket check-in',
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: CheckInPanel(service: service, scanner: scanner),
    ),
  );
}

// Staff scan the QR code on the customer's ticket (or type its code), see the
// booking and check it in. Handheld scanners type the code and press Enter,
// so the code field finds the ticket on Enter.
class CheckInPanel extends StatefulWidget {
  const CheckInPanel({
    required this.service,
    this.scanner,
    this.canScan,
    super.key,
  });

  final StaffService service;

  // Defaults to the camera scanner; tests pass their own.
  final TicketScanner? scanner;

  // Defaults to whether this platform has a camera plugin.
  final bool? canScan;

  @override
  State<CheckInPanel> createState() => _CheckInPanelState();
}

class _CheckInPanelState extends State<CheckInPanel> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Booking? _booking;
  Showtime? _showtime;
  String? _error;
  bool _busy = false;
  bool _justCheckedIn = false;

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _find([String? scanned]) async {
    if (scanned != null) _code.text = scanned.trim();
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter or scan the ticket code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _booking = null;
      _showtime = null;
      _justCheckedIn = false;
    });
    try {
      final booking = await widget.service.bookingByCode(code);
      // The room is on the showtime; the ticket is still shown without it.
      Showtime? showtime;
      try {
        showtime = await widget.service.showtime(booking.showtimeId);
      } on Object {
        showtime = null;
      }
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _showtime = showtime;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkIn(Booking booking) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await widget.service.checkIn(booking.id);
      if (!mounted) return;
      setState(() {
        _booking = updated;
        _justCheckedIn = true;
      });
      // Ready for the next ticket.
      _code.clear();
      _focus.requestFocus();
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final code = await (widget.scanner ?? openTicketScanner)(context);
    if (code != null && code.trim().isNotEmpty && mounted) await _find(code);
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    final error = _error;
    final canScan = widget.canScan ?? cameraScanSupported;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CinemaPanel(
          surfaceOpacity: 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Scan the QR code on the customer’s ticket, or type the '
                'ticket code.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                key: const Key('checkInCode'),
                controller: _code,
                focusNode: _focus,
                enabled: !_busy,
                autofocus: !canScan,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _find(),
                decoration: const InputDecoration(
                  labelText: 'Ticket code',
                  hintText: 'BK-…',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Find ticket',
                      leadingIcon: Icons.search,
                      onPressed: _busy ? null : _find,
                    ),
                  ),
                  if (canScan) ...[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: 'Scan QR',
                        leadingIcon: Icons.qr_code_scanner,
                        useGradient: true,
                        onPressed: _busy ? null : _scan,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (_busy) ...[
          const SizedBox(height: AppSpacing.md),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (error != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _Banner(
            icon: Icons.error_outline,
            color: AppColors.error,
            message: error,
          ),
        ],
        if (booking != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _TicketResult(
            booking: booking,
            showtime: _showtime,
            justCheckedIn: _justCheckedIn,
            busy: _busy,
            onCheckIn: () => _checkIn(booking),
          ),
        ],
      ],
    );
  }
}

class _TicketResult extends StatelessWidget {
  const _TicketResult({
    required this.booking,
    required this.showtime,
    required this.justCheckedIn,
    required this.busy,
    required this.onCheckIn,
  });

  final Booking booking;
  final Showtime? showtime;
  final bool justCheckedIn;
  final bool busy;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final showTime = booking.showTime;
    final checkedInAt = booking.checkedInAt;
    final room = showtime?.roomLabel;

    return CinemaPanel(
      key: const Key('checkInTicket'),
      surfaceOpacity: 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  booking.movieTitle ?? 'Movie',
                  style: AppTextStyles.heading2,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              BookingStatusBadge(
                status: booking.status,
                checkedIn: booking.isCheckedIn,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(booking.bookingCode, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.lg),
          _Fact(
            icon: Icons.schedule,
            label: 'Show',
            value: showTime == null ? 'Time TBA' : formatDateTime(showTime),
          ),
          if (room != null)
            _Fact(
              icon: Icons.meeting_room_outlined,
              label: 'Room',
              value: room,
            ),
          _Fact(
            icon: Icons.event_seat_outlined,
            label: 'Seats',
            value: '${booking.seatLabels} (${booking.seats.length})',
          ),
          _Fact(
            icon: Icons.payments_outlined,
            label: 'Total',
            value: formatVnd(booking.totalAmount),
          ),
          if (booking.customerEmail case final email?)
            _Fact(icon: Icons.mail_outline, label: 'Customer', value: email),
          const SizedBox(height: AppSpacing.md),
          if (checkedInAt != null)
            justCheckedIn
                ? _Banner(
                    icon: Icons.verified_rounded,
                    color: AppColors.success,
                    message:
                        'Checked in. Let the customer in'
                        '${room == null ? '' : ' to $room'}: '
                        'seats ${booking.seatLabels}.',
                  )
                : _Banner(
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    message:
                        'This ticket was already used: checked in '
                        '${formatDateTime(checkedInAt)}.',
                  )
          else if (booking.canCheckIn)
            AppButton(
              key: const Key('checkInButton'),
              label: 'Check in',
              leadingIcon: Icons.how_to_reg,
              useGradient: true,
              isLoading: busy,
              onPressed: busy ? null : onCheckIn,
            )
          else
            _Banner(
              icon: Icons.block,
              color: AppColors.error,
              message: switch (booking.status) {
                BookingStatus.pending => 'This ticket has not been paid yet.',
                BookingStatus.refundPending => 'A refund was requested for this ticket, so it cannot be used.',
                _ => 'This ticket was cancelled or expired and cannot be used.',
              },
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(width: 72, child: Text(label, style: AppTextStyles.bodySmall)),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) => DecoratedBox(
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
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: AppTextStyles.body)),
        ],
      ),
    ),
  );
}

// Full-screen camera that closes with the first QR code it reads.
Future<String?> openTicketScanner(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _TicketScannerPage(),
      ),
    );

class _TicketScannerPage extends StatefulWidget {
  const _TicketScannerPage();

  @override
  State<_TicketScannerPage> createState() => _TicketScannerPageState();
}

class _TicketScannerPageState extends State<_TicketScannerPage> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (_done || code == null) return;
    _done = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('Scan ticket'),
      actions: [
        IconButton(
          tooltip: 'Torch',
          icon: const Icon(Icons.flashlight_on_outlined),
          onPressed: _controller.toggleTorch,
        ),
      ],
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'The camera could not start (${error.errorCode.name}). '
                'Allow camera access, or type the ticket code instead.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
        // Where to hold the ticket.
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.xxxl,
          child: Text(
            'Hold the QR code on the customer’s ticket inside the frame.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
