import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/account_validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/models/auth_response.dart';
import '../../../data/repositories/auth_repository.dart';

String _message(Object error) => error is ApiException
    ? error.message
    : 'Something went wrong. Please try again.';

// Name and phone number; returns the saved account. The email is the sign-in
// name and cannot change.
class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({
    required this.repository,
    required this.user,
    super.key,
  });

  final AuthRepository repository;
  final AuthUser user;

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _phone = TextEditingController(text: widget.user.phone);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = await widget.repository.updateProfile(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
      );
      if (mounted) Navigator.pop(context, user);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _message(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountDialog(
      title: 'Edit profile',
      form: _form,
      error: _error,
      saving: _saving,
      saveKey: const Key('saveProfile'),
      onSave: _save,
      fields: [
        Text(widget.user.email, style: AppTextStyles.bodySmall),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          key: const Key('profileNameField'),
          label: 'Full name',
          controller: _name,
          enabled: !_saving,
          validator: validateFullName,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          key: const Key('profilePhoneField'),
          label: 'Phone (optional)',
          controller: _phone,
          enabled: !_saving,
          keyboardType: TextInputType.phone,
          validator: validatePhone,
        ),
      ],
    );
  }
}

// The current password and a new one (twice). Returns true once changed;
// other devices are signed out, this one stays signed in.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({
    required this.repository,
    required this.onForgotPassword,
    super.key,
  });

  final AuthRepository repository;

  // Forgot the current password: the email code flow instead.
  final VoidCallback onForgotPassword;

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_current, _new, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.changePassword(
        currentPassword: _current.text,
        newPassword: _new.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _message(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AccountDialog(
      title: 'Change password',
      form: _form,
      error: _error,
      saving: _saving,
      saveKey: const Key('savePassword'),
      onSave: _save,
      fields: [
        AppTextField(
          key: const Key('currentPasswordField'),
          label: 'Current password',
          controller: _current,
          enabled: !_saving,
          obscureText: true,
          validator: validateSignInPassword,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('forgotCurrentPassword'),
            onPressed: _saving ? null : widget.onForgotPassword,
            child: const Text('Forgot it? Reset by email'),
          ),
        ),
        AppTextField(
          key: const Key('newPasswordField'),
          label: 'New password',
          controller: _new,
          enabled: !_saving,
          obscureText: true,
          validator: validateNewPassword,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          key: const Key('confirmPasswordField'),
          label: 'Repeat the new password',
          controller: _confirm,
          enabled: !_saving,
          obscureText: true,
          validator: (value) => validatePasswordConfirmation(value, _new.text),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Other devices will be signed out.',
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}

class _AccountDialog extends StatelessWidget {
  const _AccountDialog({
    required this.title,
    required this.form,
    required this.fields,
    required this.error,
    required this.saving,
    required this.saveKey,
    required this.onSave,
  });

  final String title;
  final GlobalKey<FormState> form;
  final List<Widget> fields;
  final String? error;
  final bool saving;
  final Key saveKey;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: CinemaPanel(
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: AppTextStyles.heading2),
                  const SizedBox(height: AppSpacing.lg),
                  ...fields,
                  if (error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      error!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.secondary(
                          label: 'Cancel',
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          key: saveKey,
                          label: 'Save',
                          useGradient: true,
                          isLoading: saving,
                          onPressed: saving ? null : onSave,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
