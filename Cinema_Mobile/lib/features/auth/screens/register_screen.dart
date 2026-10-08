import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/repositories/auth_repository.dart';
import '../auth_error_messages.dart';
import '../widgets/auth_scaffold.dart';
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
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Book tickets and enjoy your favorite movies.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFieldSurface(
              child: AppTextField(
                label: 'Full name',
                isRequired: true,
                hint: 'Enter your full name',
                controller: _fullNameController,
                enabled: !_isLoading,
                keyboardType: TextInputType.name,
                prefixIcon: const Icon(Icons.person_outline),
                validator: _validateFullName,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthFieldSurface(
              child: AppTextField(
                label: 'Email',
                isRequired: true,
                hint: 'you@example.com',
                controller: _emailController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined),
                validator: _validateEmail,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthFieldSurface(
              child: AppTextField(
                label: 'Phone number',
                hint: 'Enter your phone number',
                controller: _phoneController,
                enabled: !_isLoading,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined),
                validator: _validatePhone,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthFieldSurface(
              child: AppTextField(
                label: 'Password',
                isRequired: true,
                hint: 'Create a strong password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                enabled: !_isLoading,
                prefixIcon: const Icon(Icons.lock_outline),
                validator: _validatePassword,
                onChanged: (value) {
                  if (value.isEmpty && !_obscurePassword) {
                    setState(() => _obscurePassword = true);
                  }
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
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AuthStatusMessage.error(message: _errorMessage!),
            ],
            const SizedBox(height: AppSpacing.xxl),
            AuthButton(
              label: 'Create account',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _register,
            ),
            const SizedBox(height: AppSpacing.md),
            AuthButton.secondary(
              label: 'Already have an account? Sign in',
              onPressed: _isLoading ? null : () => Navigator.pop(context),
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
