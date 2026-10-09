import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/session/session_state.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_success_dialog.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/repositories/auth_repository.dart';
import '../auth_error_messages.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword(String email) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authRepository.resetPassword(
        email: email,
        otp: _otpController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;

      await widget.authRepository.logout();
      if (!mounted) return;
      SessionProvider.of(context).clear();
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Password reset successful',
        barrierColor: Colors.black.withValues(alpha: 0.72),
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        pageBuilder: (context, _, _) => const Material(
          type: MaterialType.transparency,
          child: AuthSuccessDialog(
            title: 'Password reset!',
            message: 'Your password has been updated.\nPlease sign in again.',
            footer: 'Taking you to sign in…',
          ),
        ),
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } on ApiException catch (error) {
      _showError(authErrorMessage(error));
    } on FormatException {
      _showError('The server returned an invalid response.');
    } on Object {
      _showError('Something went wrong. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = ModalRoute.of(context)?.settings.arguments as String?;

    if (email == null || email.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Reset password'),
        ),
        body: Center(
          child: AppButton.secondary(
            label: 'Request a new code',
            onPressed: () => Navigator.pushReplacementNamed(
              context,
              AppRoutes.forgotPassword,
            ),
          ),
        ),
      );
    }

    return AuthScaffold(
      showBack: false,
      title: 'Set a new password',
      subtitle: 'Enter the verification code sent to $email.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFieldSurface(
              child: AppTextField(
                isRequired: true,
                controller: _otpController,
                label: 'Verification code',
                hint: '123456',
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                prefixIcon: const Icon(Icons.pin_outlined),
                validator: (value) {
                  final otp = value?.trim() ?? '';
                  if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
                    return 'Enter the 6-digit code from your email.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthFieldSurface(
              child: AppTextField(
                isRequired: true,
                controller: _passwordController,
                label: 'New password',
                hint: 'Enter new password',
                obscureText: _obscurePassword,
                enabled: !_isLoading,
                prefixIcon: const Icon(Icons.lock_outline),
                validator: (value) {
                  if ((value ?? '').length < 6) {
                    return 'Password must be at least 6 characters.';
                  }
                  return null;
                },
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthFieldSurface(
              child: AppTextField(
                label: 'Confirm new password',
                hint: 'Re-enter your new password',
                controller: _confirmController,
                enabled: !_isLoading,
                isRequired: true,
                obscureText: _obscureConfirmPassword,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscureConfirmPassword
                      ? 'Show confirm password'
                      : 'Hide confirm password',
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        }),
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) =>
                    value != _passwordController.text || (value ?? '').isEmpty
                    ? 'Passwords do not match.'
                    : null,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                liveRegion: true,
                child: Text(
                  _errorMessage!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Reset password',
              useGradient: true,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : () => _resetPassword(email),
            ),
          ],
        ),
      ),
    );
  }
}
