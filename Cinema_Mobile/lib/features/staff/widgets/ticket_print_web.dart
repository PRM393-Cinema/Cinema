import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui' as ui;

import 'package:qr_flutter/qr_flutter.dart';
import 'package:web/web.dart' as web;

import '../../../core/utils/formatters.dart';
import '../../../data/models/booking.dart';

const canPrintTicket = true;

// Opens the ticket in a new tab, sized for a receipt printer, with the QR code
// staff scan at the entrance, and starts the browser's print dialog.
Future<void> printTicket(Booking booking) async {
  // Opened before anything is awaited, while the click still allows pop-ups.
  final tab = web.window.open('', '_blank');
  if (tab == null) {
    throw const FormatException(
      'The browser blocked the ticket window. Allow pop-ups for this site and '
      'print again.',
    );
  }

  final png = await QrPainter(
    data: booking.bookingCode,
    version: QrVersions.auto,
    gapless: true,
  ).toImageData(480, format: ui.ImageByteFormat.png);
  final qr = png == null
      ? ''
      : '<img src="data:image/png;base64,'
            '${base64Encode(png.buffer.asUint8List())}" alt="">';

  final html = _ticketHtml(booking, qr);
  final blob = web.Blob(
    <web.BlobPart>[html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  tab.location.href = web.URL.createObjectURL(blob);
}

String _ticketHtml(Booking booking, String qr) {
  const escape = HtmlEscape();
  String row(String label, String value) =>
      '<div class="row"><span>${escape.convert(label)}</span>'
      '<b>${escape.convert(value)}</b></div>';

  return '''<!doctype html>
<html><head><meta charset="utf-8">
<title>Ticket ${escape.convert(booking.bookingCode)}</title>
<style>
@page { size: 80mm auto; margin: 4mm; }
body { font-family: system-ui, sans-serif; color: #000; margin: 0 auto; max-width: 72mm; text-align: center; }
h1 { font-size: 15px; letter-spacing: 2px; margin: 6px 0 2px; }
h2 { font-size: 17px; margin: 8px 0; }
.row { display: flex; justify-content: space-between; gap: 8px; font-size: 12px; margin: 3px 0; text-align: left; }
.row b { text-align: right; }
hr { border: 0; border-top: 1px dashed #000; margin: 8px 0; }
img { width: 46mm; height: 46mm; image-rendering: pixelated; }
.code { font: 600 13px monospace; letter-spacing: 0.5px; }
small { font-size: 10px; }
</style></head>
<body>
<h1>COSMOQ CINEMA</h1>
<small>Movie ticket</small>
<hr>
<h2>${escape.convert(booking.movieTitle ?? 'Movie')}</h2>
${booking.showTime == null ? '' : row('Showtime', formatDateTime(booking.showTime!))}
${row('Seats', booking.seatLabels)}
${booking.concessions.isEmpty ? '' : row('Snacks', booking.snacksText)}
${booking.hasDiscount ? row('Discount', booking.discountText) : ''}
${booking.pointsUsed > 0 ? row('Points', booking.pointsUsedText) : ''}
${row('Total', formatVnd(booking.totalAmount))}
${row('Status', booking.isCheckedIn ? 'Checked in' : 'Paid')}
<hr>
$qr
<div class="code">${escape.convert(booking.bookingCode)}</div>
<small>Show this QR code at the entrance.</small>
<script>addEventListener('load', function () { setTimeout(function () { print(); }, 200); });</script>
</body></html>''';
}
