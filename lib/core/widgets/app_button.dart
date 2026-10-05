import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.leadingIcon,
    super.key,
  });

  const AppButton.secondary({
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.leadingIcon,
    super.key,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.danger({
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.leadingIcon,
    super.key,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? leadingIcon;

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = _ButtonColors.fromVariant(variant);

    return SizedBox(
      height: AppSpacing.xxxl,
      child: ElevatedButton(
        onPressed: _isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.background,
          foregroundColor: colors.foreground,
          disabledBackgroundColor: variant == AppButtonVariant.secondary
              ? AppColors.surface
              : AppColors.surfaceSoft,
          disabledForegroundColor: AppColors.textSecondary,
          elevation: 0,
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusMd),
          textStyle: AppTextStyles.button,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
        child: _ButtonContent(
          label: label,
          isLoading: isLoading,
          leadingIcon: leadingIcon,
        ),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.isLoading,
    this.leadingIcon,
  });

  final String label;
  final bool isLoading;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox.square(
        dimension: AppSpacing.xl,
        child: CircularProgressIndicator(strokeWidth: AppSpacing.xs),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: AppSpacing.xl),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _ButtonColors {
  const _ButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  factory _ButtonColors.fromVariant(AppButtonVariant variant) {
    return switch (variant) {
      AppButtonVariant.primary => const _ButtonColors(
        background: AppColors.primary,
        foreground: AppColors.textPrimary,
        border: AppColors.primary,
      ),
      AppButtonVariant.secondary => const _ButtonColors(
        background: AppColors.surface,
        foreground: AppColors.textPrimary,
        border: AppColors.border,
      ),
      AppButtonVariant.danger => const _ButtonColors(
        background: AppColors.error,
        foreground: AppColors.textPrimary,
        border: AppColors.error,
      ),
    };
  }

  final Color background;
  final Color foreground;
  final Color border;
}
