import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';

class SeatHoldTimer extends StatelessWidget {
  const SeatHoldTimer({
    required this.remaining,
    required this.expired,
    super.key,
  });

  final Duration? remaining;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final isUrgent =
        expired ||
        (remaining != null && remaining! < const Duration(minutes: 2));
    final color = expired
        ? AppColors.error
        : (isUrgent ? AppColors.warning : AppColors.primary);

    final text = expired
        ? 'Your seat hold has expired. Please book again.'
        : remaining == null
        ? 'Your seats are held while you pay.'
        : 'Seats held for ${formatCountdown(remaining!)}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                text,
                key: const Key('holdTimerText'),
                style: AppTextStyles.title.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
