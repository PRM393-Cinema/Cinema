import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/repositories/auth_repository.dart';
import '../auth_error_messages.dart';
import '../verify_email_arguments.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  VerifyEmailArguments? _arguments;
  bool _initialized = false;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;
  DateTime? _resendAvailableAt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is VerifyEmailArguments) {
      _arguments = args;
      _emailController.text = args.email;
      _setResendCooldown(args.resendAfterSeconds);
    } else {
      _errorMessage =
          'Registration details are missing. Please create your account again.';
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  int get _remainingResendSeconds {
    final availableAt = _resendAvailableAt;
    if (availableAt == null) {
      return 0;
    }

    final remaining = availableAt.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  bool get _hasRoutePayload => _arguments != null;

  Future<void> _verifyEmail() async {
    FocusScope.of(context).unfocus();
    final args = _arguments;
    if (args == null) {
      _showError(
        'Registration details are missing. Please create your account again.',
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await widget.authRepository.verifyEmail(
        email: args.email,
        otp: _otpController.text.trim(),
        password: args.password,
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } on ApiException catch (error) {
      _showError(authErrorMessage(error));
    } on FormatException {
      _showError('The server returned an invalid response.');
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    }
  }

  Future<void> _resendCode() async {
    final args = _arguments;
    if (args == null || _remainingResendSeconds > 0) {
      return;
    }

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await widget.authRepository.resendVerification(
        email: args.email,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isResending = false;
        _successMessage = 'A new verification code has been sent.';
      });
      _setResendCooldown(response.resendAfterSeconds);
    } on ApiException catch (error) {
      _showError(authErrorMessage(error));
    } on FormatException {
      _showError('The server returned an invalid response.');
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    }
  }

  void _setResendCooldown(int seconds) {
    if (seconds <= 0) {
      _resendAvailableAt = null;
      return;
    }
    _resendAvailableAt = DateTime.now().add(Duration(seconds: seconds));
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isVerifying = false;
      _isResending = false;
      _successMessage = null;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final remainingSeconds = _remainingResendSeconds;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Verify your email',
                      style: AppTextStyles.heading1,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Enter the verification code sent to your email.',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    if (_hasRoutePayload) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Code sent to ${_arguments!.email}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    AppTextField(
                      label: 'Email',
                      hint: 'you@example.com',
                      controller: _emailController,
                      enabled: false,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Verification code',
                      hint: '123456',
                      controller: _otpController,
                      enabled: !_isVerifying && _hasRoutePayload,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.pin_outlined),
                      validator: _validateOtp,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _AuthStatusMessage.error(message: _errorMessage!),
                    ],
                    if (_successMessage != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _AuthStatusMessage.success(message: _successMessage!),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    AppButton(
                      label: 'Verify email',
                      isLoading: _isVerifying,
                      onPressed: _isVerifying || !_hasRoutePayload
                          ? null
                          : _verifyEmail,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton.secondary(
                      label: remainingSeconds > 0
                          ? 'Resend code (${remainingSeconds}s)'
                          : 'Resend code',
                      isLoading: _isResending,
                      onPressed:
                          _isVerifying ||
                              _isResending ||
                              !_hasRoutePayload ||
                              remainingSeconds > 0
                          ? null
                          : _resendCode,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _validateOtp(String? value) {
  final otp = value?.trim() ?? '';
  if (otp.isEmpty) {
    return 'Verification code is required.';
  }
  if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
    return 'Verification code must be 6 digits.';
  }
  return null;
}

class _AuthStatusMessage extends StatelessWidget {
  const _AuthStatusMessage._({
    required this.message,
    required this.color,
    required this.icon,
  });

  const _AuthStatusMessage.error({required String message})
    : this._(
        message: message,
        color: AppColors.error,
        icon: Icons.error_outline,
      );

  const _AuthStatusMessage.success({required String message})
    : this._(
        message: message,
        color: AppColors.success,
        icon: Icons.check_circle_outline,
      );

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.borderRadiusMd,
          border: Border.all(color: color),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: AppSpacing.xl),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
