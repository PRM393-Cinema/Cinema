import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/showtime.dart';

const seatTypes = ['NORMAL', 'VIP', 'SWEETBOX'];

const sweetboxColor = Color(0xFFEC4899);

String seatTypeLabel(String type) => switch (type.toUpperCase()) {
  'VIP' => 'VIP',
  'SWEETBOX' => 'Sweetbox',
  _ => 'Standard',
};

// The prices of one seat of each of [types] (by default every type) at
// [showtime]; one price when they all cost the same.
Set<double> seatPricesOf(Showtime showtime, {Iterable<String>? types}) => {
  for (final type in types ?? seatTypes) showtime.priceOf(type),
};

// "90.000 ₫ / seat", or "from 90.000 ₫ / seat" when seats of [types] cost
// different prices (VIP and sweetbox seats cost more).
String seatPriceLabel(Showtime showtime, {Iterable<String>? types}) {
  final prices = seatPricesOf(showtime, types: types);
  final lowest = prices.isEmpty ? showtime.price : prices.reduce(math.min);
  return '${prices.length > 1 ? 'from ' : ''}${formatVnd(lowest)} / seat';
}

// The colours of a free seat of [type], the same on the customer seat map and
// on the room map of the admin website.
(Color fill, Color border, Color text) seatTypeColors(String type) =>
    switch (type.toUpperCase()) {
      'VIP' => (
        AppColors.warning.withValues(alpha: 0.18),
        AppColors.warning,
        AppColors.warning,
      ),
      'SWEETBOX' => (
        sweetboxColor.withValues(alpha: 0.18),
        sweetboxColor,
        sweetboxColor,
      ),
      _ => (AppColors.surface, AppColors.border, AppColors.textPrimary),
    };
