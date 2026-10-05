import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

class ShowtimeChip extends StatelessWidget {
  const ShowtimeChip({
    required this.time,
    this.price,
    this.isSelected = false,
    this.isAvailable = true,
    this.onTap,
    super.key,
  });

  final String time;
  final String? price;
  final bool isSelected;
  final bool isAvailable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isAvailable
        ? AppColors.textPrimary
        : AppColors.textSecondary;
    final borderColor = isSelected ? AppColors.primary : AppColors.border;
    final backgroundColor = isSelected
        ? AppColors.primaryDark
        : AppColors.surface;

    return InkWell(
      onTap: isAvailable ? onTap : null,
      borderRadius: AppRadius.borderRadiusMd,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.borderRadiusMd,
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: AppTextStyles.button.copyWith(color: foregroundColor),
              ),
              if (price != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  price!,
                  style: AppTextStyles.caption.copyWith(color: foregroundColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
