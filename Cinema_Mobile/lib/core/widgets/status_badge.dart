import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';

enum StatusBadgeVariant { success, warning, error, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    this.variant = StatusBadgeVariant.neutral,
    super.key,
  });

  final String label;
  final StatusBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final color = switch (variant) {
      StatusBadgeVariant.success => AppPalette.of(context).success,
      StatusBadgeVariant.warning => AppPalette.of(context).warning,
      StatusBadgeVariant.error => AppPalette.of(context).error,
      StatusBadgeVariant.neutral => AppPalette.of(context).textSecondary,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.of(context).surfaceSoft,
        borderRadius: AppRadius.borderRadiusSm,
        border: Border.all(color: AppPalette.of(context).border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: AppSpacing.sm, color: color),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
