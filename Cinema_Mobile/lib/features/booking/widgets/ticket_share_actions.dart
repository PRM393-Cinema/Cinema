import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/top_notice.dart';
import '../../../data/models/booking.dart';
import '../../../data/repositories/catalog_repository.dart';

// What friends get when a ticket is shared: the show and the ticket code,
// which staff can look up at the entrance.
String ticketShareText(Booking booking) {
  final showTime = booking.showTime;
  return [
    '🎬 ${booking.movieTitle ?? 'Movie ticket'}',
    if (showTime != null) '🕒 ${formatDateTime(showTime)}',
    if (booking.seatLabels.isNotEmpty) '💺 Seats ${booking.seatLabels}',
    '🎟 Ticket ${booking.bookingCode}',
    'CosmoQ Cinema · show the code or the QR on the ticket at the entrance.',
  ].join('\n');
}

// A Google Calendar event for the show, in Vietnam time.
Uri calendarEventUri(Booking booking, DateTime start, DateTime end) {
  final format = DateFormat("yyyyMMdd'T'HHmmss");
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': '${booking.movieTitle ?? 'Movie'} – CosmoQ Cinema',
    'dates': '${format.format(start)}/${format.format(end)}',
    'ctz': 'Asia/Ho_Chi_Minh',
    'details':
        'Seats ${booking.seatLabels}\nTicket ${booking.bookingCode}\n'
        'Arrive 15 minutes early and show the QR code on your ticket.',
    'location': 'CosmoQ Cinema',
  });
}

typedef TextSharer = Future<void> Function(String text, String subject);

Future<void> _shareWithSheet(String text, String subject) async {
  await SharePlus.instance.share(ShareParams(text: text, subject: subject));
}

// "Share ticket" and "Add to calendar" on a paid ticket.
class TicketShareActions extends StatefulWidget {
  const TicketShareActions({
    required this.booking,
    this.catalogRepository,
    this.share = defaultShare,
    super.key,
  });

  final Booking booking;

  // Reads the showtime for its end; without it the event lasts 2.5 hours.
  final CatalogRepository? catalogRepository;

  // The share sheet; tests pass their own.
  final TextSharer share;

  static const fallbackLength = Duration(minutes: 150);

  static const TextSharer defaultShare = _shareWithSheet;

  @override
  State<TicketShareActions> createState() => _TicketShareActionsState();
}

class _TicketShareActionsState extends State<TicketShareActions> {
  bool _busy = false;

  Future<void> _share() async {
    final text = ticketShareText(widget.booking);
    try {
      await widget.share(text, 'Movie ticket ${widget.booking.bookingCode}');
    } on Object {
      // No share sheet (e.g. a desktop browser): copy it instead.
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        showTopNotice(
          Overlay.of(context, rootOverlay: true),
          'Ticket details copied. Paste them to your friends.',
        );
      }
    }
  }

  Future<void> _addToCalendar() async {
    final start = widget.booking.showTime;
    if (start == null) return;
    setState(() => _busy = true);
    var end = start.add(TicketShareActions.fallbackLength);
    try {
      final showtime = await widget.catalogRepository?.getShowtime(
        widget.booking.showtimeId,
      );
      if (showtime != null && showtime.endTime.isAfter(start)) {
        end = showtime.endTime;
      }
    } on Object {
      // Keep the estimated length.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await launchUrl(
      calendarEventUri(widget.booking, start, end),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  @override
  Widget build(BuildContext context) {
    final showTime = widget.booking.showTime;
    final upcoming = showTime != null && showTime.isAfter(DateTime.now());
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        OutlinedButton.icon(
          key: const Key('shareTicket'),
          onPressed: _share,
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('Share ticket'),
        ),
        if (upcoming)
          OutlinedButton.icon(
            key: const Key('addToCalendar'),
            onPressed: _busy ? null : _addToCalendar,
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Add to calendar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warning,
              side: const BorderSide(color: AppColors.warning),
            ),
          ),
      ],
    );
  }
}
