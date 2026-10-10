import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../auth/widgets/auth_success_dialog.dart';

String staffError(Object error) => error is ApiException
    ? error.message
    : error is FormatException
    ? error.message
    : 'Unable to complete the request. Please try again.';
EdgeInsets staffPadding(BuildContext context) => centeredPadding(
  context,
  AppSpacing.lg,
).copyWith(bottom: 112 + MediaQuery.viewPaddingOf(context).bottom);

Future<bool> staffConfirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: CinemaPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTextStyles.heading2),
              const SizedBox(height: AppSpacing.md),
              Text(message, style: AppTextStyles.bodySmall),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Back',
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Confirm',
                      useGradient: true,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ??
    false;

Future<String?> staffInput(
  BuildContext context,
  String title,
  String label, {
  String initial = '',
  int maxLength = 500,
  bool email = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _StaffInputDialog(
    title: title,
    label: label,
    initial: initial,
    maxLength: maxLength,
    email: email,
  ),
);

class _StaffInputDialog extends StatefulWidget {
  const _StaffInputDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.maxLength,
    required this.email,
  });
  final String title;
  final String label;
  final String initial;
  final int maxLength;
  final bool email;
  @override
  State<_StaffInputDialog> createState() => _StaffInputDialogState();
}

class _StaffInputDialogState extends State<_StaffInputDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: CinemaPanel(
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: AppTextStyles.heading2),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: widget.label,
                controller: _controller,
                keyboardType: widget.email
                    ? TextInputType.emailAddress
                    : TextInputType.text,
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Required.'
                    : value!.trim().length > widget.maxLength
                    ? 'Maximum ${widget.maxLength} characters.'
                    : widget.email &&
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(value.trim())
                    ? 'Enter a valid email.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Continue',
                      useGradient: true,
                      onPressed: () {
                        if (_form.currentState!.validate()) {
                          Navigator.pop(context, _controller.text.trim());
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> staffSuccess(
  BuildContext context,
  String message, {
  bool cancelled = false,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'Operation complete',
  barrierColor: Colors.black.withValues(alpha: 0.72),
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 180),
  pageBuilder: (_, _, _) => Material(
    type: MaterialType.transparency,
    child: AuthSuccessDialog(
      title: cancelled ? 'Cancelled' : 'Done',
      message: message,
      footer: 'Staff workspace',
      isCancellation: cancelled,
    ),
  ),
  transitionBuilder: (_, animation, _, child) =>
      FadeTransition(opacity: animation, child: child),
);
