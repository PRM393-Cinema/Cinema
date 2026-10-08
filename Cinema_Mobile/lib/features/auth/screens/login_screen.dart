import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/session/session_state.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/repositories/auth_repository.dart';
import '../auth_error_messages.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      SessionProvider.of(context).setAuthenticated(response.user);

      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final pendingRoute = args?['pendingRoute'] as String?;
      final pendingArguments = args?['pendingArguments'];

      if (pendingRoute != null) {
        Navigator.pushReplacementNamed(
          context,
          pendingRoute,
          arguments: pendingArguments,
        );
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
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
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandMark(),
                    const SizedBox(height: AppSpacing.xxl),
                    const Text(
                      'Welcome back',
                      style: AppTextStyles.heading1,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Sign in to continue your cinema experience.',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AppTextField(
                      label: 'Email',
                      hint: 'you@example.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Password',
                      hint: 'Enter your password',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isLoading,
                      prefixIcon: const Icon(Icons.lock_outline),
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
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pushNamed(
                                context,
                                AppRoutes.forgotPassword,
                              ),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      _LoginError(message: _errorMessage!),
                      const SizedBox(height: AppSpacing.lg),
                    ] else
                      const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Sign in',
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _login,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton.secondary(
                      label: 'Create an account',
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pushNamed(
                              context,
                              AppRoutes.register,
                            ),
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

String? _validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required.';
  }
  return null;
}

class _LoginError extends StatelessWidget {
  const _LoginError({required this.message});

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

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.borderRadiusLg,
            border: Border.all(color: AppColors.border),
          ),
          child: const SizedBox.square(
            dimension: AppSpacing.xxxl * 1.5,
            child: Icon(
              Icons.local_movies_outlined,
              color: AppColors.primary,
              size: AppSpacing.xxxl,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('CosmoQ Cinema', style: AppTextStyles.display),
      ],
    );
  }
}
