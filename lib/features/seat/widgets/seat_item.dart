import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

enum SeatItemState { available, selected, held, booked }

class SeatItem extends StatelessWidget {
  const SeatItem({
    required this.label,
    this.state = SeatItemState.available,
    this.onTap,
    super.key,
  });

  final String label;
  final SeatItemState state;
  final VoidCallback? onTap;

  bool get _canTap =>
      state == SeatItemState.available || state == SeatItemState.selected;

  @override
  Widget build(BuildContext context) {
    final style = _SeatStyle.fromState(state);

    return InkWell(
      onTap: _canTap ? onTap : null,
      borderRadius: AppRadius.borderRadiusSm,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: AppRadius.borderRadiusSm,
          border: Border.all(color: style.border),
        ),
        child: SizedBox.square(
          dimension: AppSpacing.xxxl,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(color: style.foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatStyle {
  const _SeatStyle({
    required this.background,
    required this.foreground,
    required this.border,
  });

  factory _SeatStyle.fromState(SeatItemState state) {
    return switch (state) {
      SeatItemState.available => const _SeatStyle(
        background: AppColors.surface,
        foreground: AppColors.textPrimary,
        border: AppColors.border,
      ),
      SeatItemState.selected => const _SeatStyle(
        background: AppColors.primary,
        foreground: AppColors.textPrimary,
        border: AppColors.primary,
      ),
      SeatItemState.held => const _SeatStyle(
        background: AppColors.surfaceSoft,
        foreground: AppColors.textSecondary,
        border: AppColors.warning, // distinct visual for held
      ),
      SeatItemState.booked => const _SeatStyle(
        background: AppColors.surfaceSoft,
        foreground: AppColors.textSecondary,
        border: AppColors.surfaceSoft,
      ),
    };
  }

  final Color background;
  final Color foreground;
  final Color border;
}
