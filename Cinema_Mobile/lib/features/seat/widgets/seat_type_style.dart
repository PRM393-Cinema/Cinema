import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

const seatTypes = ['NORMAL', 'VIP', 'SWEETBOX'];

const sweetboxColor = Color(0xFFEC4899);

String seatTypeLabel(String type) => switch (type.toUpperCase()) {
  'VIP' => 'VIP',
  'SWEETBOX' => 'Sweetbox',
  _ => 'Standard',
};

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
