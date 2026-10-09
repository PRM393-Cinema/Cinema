import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../widgets/auth_scaffold.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/repositories/auth_repository.dart';
import '../auth_error_messages.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _hasPrefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasPrefilled) {
      _hasPrefilled = true;
      final email = ModalRoute.of(context)?.settings.arguments;
      if (email is String) _emailController.text = email;
    }
  }

  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSendResetCode() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.authRepository.forgotPassword(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.resetPassword,
        arguments: response.email,
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
    final changingPassword =
        ModalRoute.of(context)?.settings.arguments is String;
    return AuthScaffold(
      showBack: false,
      title: changingPassword ? 'Change password' : 'Forgot password?',
      subtitle: 'We will send a verification code to your email to keep your account secure.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFieldSurface(
              child: AppTextField(
                isRequired: true,
                controller: _emailController,
                label: 'Email',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                prefixIcon: const Icon(Icons.email_outlined),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Email is required.';
                  if (!email.contains('@')) {
                    return 'Please enter a valid email address.';
                  }
                  return null;
                },
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
              label: 'Send verification code',
              useGradient: true,
              trailingIcon: Icons.arrow_forward_rounded,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _onSendResetCode,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton.secondary(
              label: changingPassword ? 'Back to account' : 'Back to login',
              onPressed: _isLoading
                  ? null
                  : () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.login,
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
