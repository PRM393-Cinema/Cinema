import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import 'seat_item.dart';

class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      alignment: WrapAlignment.center,
      children: [
        _SeatLegendEntry(label: 'Available', state: SeatItemState.available),
        _SeatLegendEntry(label: 'Selected', state: SeatItemState.selected),
        // Seats held by other customers are reported together with booked
        // seats, so both show as unavailable.
        _SeatLegendEntry(label: 'Unavailable', state: SeatItemState.booked),
      ],
    );
  }
}

class _SeatLegendEntry extends StatelessWidget {
  const _SeatLegendEntry({required this.label, required this.state});

  static const _swatchSize = 18.0;

  final String label;
  final SeatItemState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SeatItem(label: '', state: state, size: _swatchSize),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
