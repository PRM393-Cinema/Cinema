import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import 'seat_item.dart';
import 'seat_type_style.dart';

class SeatLegend extends StatelessWidget {
  const SeatLegend({this.types = const {'NORMAL'}, this.priceOf, super.key});

  // The seat types of the room (NORMAL, VIP, SWEETBOX); each gets an entry.
  final Set<String> types;

  // The price of one seat of a type, shown next to it; a sweetbox shows the
  // price of the couple.
  final double Function(String type)? priceOf;

  String? _priceLabel(String type) {
    final price = priceOf?.call(type);
    if (price == null) return null;
    return type == 'SWEETBOX'
        ? '${formatVnd(price * 2)} / pair'
        : formatVnd(price);
  }

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
              price: _priceLabel(type),
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
    this.price,
  });

  static const _swatchSize = 18.0;

  final String label;
  final SeatItemState state;
  final String type;
  final String? price;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SeatItem(label: '', state: state, type: type, size: _swatchSize),
        const SizedBox(width: AppSpacing.sm),
        // Long entries wrap on narrow phones and large text sizes instead of
        // running off the screen.
        Flexible(child: Text(label, style: AppTextStyles.bodySmall)),
        if (price case final price?) ...[
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              price,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
