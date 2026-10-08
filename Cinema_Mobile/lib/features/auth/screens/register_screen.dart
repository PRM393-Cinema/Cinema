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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final response = await widget.authRepository.register(
        fullName: _fullNameController.text.trim(),
        email: email,
        phone: _phoneController.text.trim(),
        password: password,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      Navigator.pushNamed(
        context,
        AppRoutes.verifyEmail,
        arguments: VerifyEmailArguments(
          email: response.email,
          password: password,
          expiresInSeconds: response.expiresInSeconds,
          resendAfterSeconds: response.resendAfterSeconds,
        ),
      );
    } on ApiException catch (error) {
      _showError(authErrorMessage(error));
    } on FormatException {
      _showError('The server returned an invalid response.');
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _RegisterTitle(key: Key('registerTitle')),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Join us for a premium movie booking experience',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        AppTextField(
                          key: const Key('registerFullNameField'),
                          label: 'Full Name',
                          labelAbove: true,
                          hint: 'John Doe',
                          controller: _fullNameController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.name,
                          validator: _validateFullName,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          key: const Key('registerEmailField'),
                          label: 'Email Address',
                          labelAbove: true,
                          hint: 'johndoe@example.com',
                          controller: _emailController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          key: const Key('registerPhoneField'),
                          label: 'Phone Number (Optional)',
                          labelAbove: true,
                          hint: '0912345678',
                          controller: _phoneController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.phone,
                          validator: _validatePhone,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          key: const Key('registerPasswordField'),
                          label: 'Password',
                          labelAbove: true,
                          hint: 'Enter your password',
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          enabled: !_isLoading,
                          validator: _validatePassword,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
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
                        if (_errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _AuthError(message: _errorMessage!),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: 'REGISTER',
                          useGradient: true,
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _register,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: AppTextStyles.caption,
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: AppColors.primary,
                                textStyle: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('Log in here'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _validateFullName(String? value) {
  if ((value?.trim() ?? '').isEmpty) {
    return 'Full name is required.';
  }
  return null;
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Email is required.';
  }
  if (!email.contains('@')) {
    return 'Please enter a valid email address.';
  }
  return null;
}

String? _validatePhone(String? value) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) {
    return null;
  }
  if (phone.length > 20 || !RegExp(r'^[0-9+(). -]+$').hasMatch(phone)) {
    return 'Please enter a valid phone number.';
  }
  return null;
}

String? _validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) {
    return 'Password is required.';
  }
  if (password.length < 6) {
    return 'Password must be at least 6 characters.';
  }
  return null;
}

class _AuthError extends StatelessWidget {
  const _AuthError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: AppRadius.borderRadiusMd,
          border: Border.all(color: AppColors.error),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: AppSpacing.xl,
              ),
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

class _RegisterTitle extends StatelessWidget {
  const _RegisterTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppTextStyles.heading2.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: AppColors.textPrimary,
        ),
        children: const [
          TextSpan(text: 'CREATE '),
          TextSpan(
            text: 'ACCOUNT',
            style: TextStyle(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
