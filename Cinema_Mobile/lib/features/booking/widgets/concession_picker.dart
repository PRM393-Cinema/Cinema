import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../data/models/concession.dart';

// Snacks and drinks added to the tickets: each item of the menu with − and +
// buttons. Used by the customer's booking summary and the counter.
class ConcessionPicker extends StatelessWidget {
  const ConcessionPicker({
    required this.items,
    required this.quantities,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  // The most of one item in a booking (the API allows 20).
  static const maxQuantity = 20;

  final List<ConcessionItem> items;
  final Map<int, int> quantities;
  final void Function(int itemId, int quantity) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0)
            const Divider(height: AppSpacing.lg, color: AppColors.border),
          _Line(
            item: item,
            quantity: quantities[item.id] ?? 0,
            onChanged: enabled ? (value) => onChanged(item.id, value) : null,
          ),
        ],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.item,
    required this.quantity,
    required this.onChanged,
  });

  final ConcessionItem item;
  final int quantity;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Row(
      key: ValueKey('snack-${item.id}'),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item.imageUrl.isEmpty
              ? Container(
                  width: 48,
                  height: 48,
                  color: AppColors.surfaceSoft,
                  child: const Icon(
                    Icons.fastfood_outlined,
                    color: AppColors.accent,
                  ),
                )
              : AppNetworkImage(imageUrl: item.imageUrl, width: 48, height: 48),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: AppTextStyles.title),
              if (item.description.isNotEmpty)
                Text(
                  item.description,
                  style: AppTextStyles.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                formatVnd(item.price),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: ValueKey('snackRemove-${item.id}'),
          tooltip: 'Remove one ${item.name}',
          onPressed: onChanged == null || quantity == 0
              ? null
              : () => onChanged(quantity - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$quantity',
            key: ValueKey('snackQuantity-${item.id}'),
            textAlign: TextAlign.center,
            style: AppTextStyles.title,
          ),
        ),
        IconButton(
          key: ValueKey('snackAdd-${item.id}'),
          tooltip: 'Add one ${item.name}',
          onPressed:
              onChanged == null || quantity >= ConcessionPicker.maxQuantity
              ? null
              : () => onChanged(quantity + 1),
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
        ),
      ],
    );
  }
}
