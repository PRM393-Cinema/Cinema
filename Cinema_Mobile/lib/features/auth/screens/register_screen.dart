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
import '../widgets/auth_scaffold.dart';

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
    return AuthScaffold(
      showBack: false,
      title: 'Create your account',
      titleKey: const Key('registerTitle'),
      subtitle: 'Book tickets and enjoy your favorite movies.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFieldSurface(
              child: AppTextField(
                key: const Key('registerFullNameField'),
                label: 'Full name',
                hint: 'Enter your full name',
                isRequired: true,
                prefixIcon: const Icon(Icons.person_outline),
                controller: _fullNameController,
                enabled: !_isLoading,
                keyboardType: TextInputType.name,
                validator: _validateFullName,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthFieldSurface(
              child: AppTextField(
                key: const Key('registerEmailField'),
                label: 'Email',
                hint: 'Enter your email',
                isRequired: true,
                prefixIcon: const Icon(Icons.mail_outline),
                controller: _emailController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthFieldSurface(
              child: AppTextField(
                key: const Key('registerPhoneField'),
                label: 'Phone number',
                hint: 'Optional',
                isRequired: false,
                prefixIcon: const Icon(Icons.phone_outlined),
                controller: _phoneController,
                enabled: !_isLoading,
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthFieldSurface(
              child: AppTextField(
                key: const Key('registerPasswordField'),
                label: 'Password',
                hint: 'Enter your password',
                isRequired: true,
                prefixIcon: const Icon(Icons.lock_outline),
                controller: _passwordController,
                enabled: !_isLoading,
                validator: _validatePassword,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _AuthError(message: _errorMessage!),
            ],
            const SizedBox(height: AppSpacing.xxl),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadius.borderRadiusMd,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.24),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: AppButton(
                label: 'Create account',
                trailingIcon: Icons.arrow_forward_rounded,
                useGradient: true,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _register,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton.secondary(
              label: 'Already have an account? Sign in',
              onPressed: _isLoading
                  ? null
                  : () => Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.login,
                    ),
            ),
          ],
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
