import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Prices come from the backend in Vietnamese dong.
final NumberFormat _vnd = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

String formatVnd(num amount) => _vnd.format(amount);

String formatDate(DateTime value) => DateFormat('MMM d, yyyy').format(value);

String formatLongDate(DateTime value) {
  return DateFormat('EEEE, MMM d, yyyy').format(value);
}

String formatTime(DateTime value) => DateFormat('h:mm a').format(value);

String formatDateTime(DateTime value) {
  return DateFormat('MMM d, yyyy • h:mm a').format(value);
}

// mm:ss countdown for the seat hold.
String formatCountdown(Duration remaining) {
  final safe = remaining.isNegative ? Duration.zero : remaining;
  final minutes = safe.inMinutes.toString().padLeft(2, '0');
  final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

// Group heading for a day of showtimes: "Today · Mon, Oct 6".
String formatDayHeading(DateTime value, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(value);
  final label = DateFormat('EEE, MMM d').format(value);

  return switch (day.difference(today).inDays) {
    0 => 'Today · $label',
    1 => 'Tomorrow · $label',
    _ => label,
  };
}
