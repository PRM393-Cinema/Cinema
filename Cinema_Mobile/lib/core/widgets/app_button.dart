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
    this.trailingIcon,
    this.useGradient = false,
    super.key,
  });

  const AppButton.secondary({
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.useGradient = false,
    super.key,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.danger({
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.useGradient = false,
    super.key,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool useGradient;

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = _ButtonColors.fromVariant(context, variant);
    final showGradient =
        useGradient && !_isDisabled && !AppPalette.of(context).isLight;

    return SizedBox(
      height: AppSpacing.xxxl,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: showGradient
              ? LinearGradient(
                  colors: [
                    AppPalette.of(context).primary,
                    AppPalette.of(context).primaryDark,
                  ],
                )
              : null,
          borderRadius: AppRadius.borderRadiusMd,
        ),
        child: ElevatedButton(
          onPressed: _isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: showGradient
                ? Colors.transparent
                : colors.background,
            foregroundColor: showGradient
                ? AppPalette.of(context).onPrimary
                : colors.foreground,
            disabledBackgroundColor: variant == AppButtonVariant.secondary
                ? AppPalette.of(context).surface
                : AppPalette.of(context).surfaceSoft,
            disabledForegroundColor: AppPalette.of(context).textSecondary,
            shadowColor: Colors.transparent,
            elevation: 0,
            side: BorderSide(
              color: showGradient ? Colors.transparent : colors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderRadiusMd,
            ),
            textStyle: AppTextStyles.button,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          ),
          child: _ButtonContent(
            label: label,
            isLoading: isLoading,
            leadingIcon: leadingIcon,
            trailingIcon: trailingIcon,
          ),
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
    this.trailingIcon,
  });

  final String label;
  final bool isLoading;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

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
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(trailingIcon, size: AppSpacing.xl),
        ],
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

  factory _ButtonColors.fromVariant(
    BuildContext context,
    AppButtonVariant variant,
  ) {
    return switch (variant) {
      AppButtonVariant.primary => _ButtonColors(
        background: AppPalette.of(context).primary,
        foreground: AppPalette.of(context).onPrimary,
        border: AppPalette.of(context).primary,
      ),
      AppButtonVariant.secondary => _ButtonColors(
        background: AppPalette.of(context).surface,
        foreground: AppPalette.of(context).textPrimary,
        border: AppPalette.of(context).border,
      ),
      AppButtonVariant.danger => _ButtonColors(
        background: AppPalette.of(context).error,
        foreground: Theme.of(context).colorScheme.onError,
        border: AppPalette.of(context).error,
      ),
    };
  }

  final Color background;
  final Color foreground;
  final Color border;
}
