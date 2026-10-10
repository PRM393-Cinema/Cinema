import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

class ShowtimeChip extends StatelessWidget {
  const ShowtimeChip({
    required this.time,
    this.room,
    this.price,
    this.isSelected = false,
    this.isAvailable = true,
    this.onTap,
    super.key,
  });

  final String time;
  final String? room;
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
        ? AppColors.primary.withValues(alpha: 0.14)
        : AppColors.surfaceSoft.withValues(alpha: 0.65);

    return InkWell(
      onTap: isAvailable ? onTap : null,
      borderRadius: AppRadius.borderRadiusMd,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              backgroundColor,
              AppColors.surface.withValues(alpha: 0.55),
            ],
          ),
          borderRadius: AppRadius.borderRadiusMd,
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: AppTextStyles.button.copyWith(
                  color: isSelected ? AppColors.primary : foregroundColor,
                ),
              ),
              if (room != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  room!,
                  style: AppTextStyles.caption.copyWith(color: foregroundColor),
                ),
              ],
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
