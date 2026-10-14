import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import 'seat_item.dart';
import 'seat_type_style.dart';

class SeatLegend extends StatelessWidget {
  const SeatLegend({this.types = const {'NORMAL'}, super.key});

  // The seat types of the room (NORMAL, VIP, SWEETBOX); each gets an entry.
  final Set<String> types;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      alignment: WrapAlignment.center,
      children: [
        for (final type in seatTypes)
          if (types.contains(type))
            _SeatLegendEntry(
              label: type == 'SWEETBOX'
                  ? 'Sweetbox (couple)'
                  : seatTypeLabel(type),
              state: SeatItemState.available,
              type: type,
            ),
        const _SeatLegendEntry(
          label: 'Selected',
          state: SeatItemState.selected,
        ),
        // Seats held by other customers are reported together with booked
        // seats, so both show as unavailable.
        const _SeatLegendEntry(
          label: 'Unavailable',
          state: SeatItemState.booked,
        ),
      ],
    );
  }
}

class _SeatLegendEntry extends StatelessWidget {
  const _SeatLegendEntry({
    required this.label,
    required this.state,
    this.type = 'NORMAL',
  });

  static const _swatchSize = 18.0;

  final String label;
  final SeatItemState state;
  final String type;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SeatItem(label: '', state: state, type: type, size: _swatchSize),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
