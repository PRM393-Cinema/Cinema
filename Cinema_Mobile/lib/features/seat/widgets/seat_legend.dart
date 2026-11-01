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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final type in seatTypes.where((type) => type != 'SWEETBOX'))
              if (types.contains(type))
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: _SeatLegendEntry(
                      label: seatTypeLabel(type),
                      price: _priceLabel(type),
                      state: SeatItemState.available,
                      type: type,
                    ),
                  ),
                ),
          ],
        ),
        if (types.contains('SWEETBOX')) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                const SeatItem(label: '', type: 'SWEETBOX', size: 18),
                const Text('Sweetbox (couple)', style: AppTextStyles.bodySmall),
                if (_priceLabel('SWEETBOX') case final price?)
                  Text(
                    price,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppPalette.of(context).textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: _SeatLegendEntry(
                label: 'Selected',
                state: SeatItemState.selected,
              ),
            ),
            SizedBox(width: AppSpacing.lg),
            // Seats held by other customers are reported together with booked
            // seats, so both show as unavailable.
            Flexible(
              child: _SeatLegendEntry(
                label: 'Unavailable',
                state: SeatItemState.booked,
              ),
            ),
          ],
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
        Flexible(
          child: Wrap(
            spacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(label, style: AppTextStyles.bodySmall),
              if (price case final price?)
                Text(
                  price,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppPalette.of(context).textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
