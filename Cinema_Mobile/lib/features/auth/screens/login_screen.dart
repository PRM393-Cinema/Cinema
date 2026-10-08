import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/session/session_state.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/repositories/auth_repository.dart';
import '../auth_error_messages.dart';
import '../widgets/auth_scaffold.dart';

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
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Welcome back',
    subtitle: 'Sign in to continue your cinema experience.',
    backToHome: true,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthFieldSurface(
            child: AppTextField(
              label: 'Email',
              hint: 'Email',
              isRequired: true,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
              prefixIcon: const Icon(Icons.mail_outline),
              validator: _validateEmail,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AuthFieldSurface(
            child: AppTextField(
              label: 'Password',
              hint: 'Password',
              isRequired: true,
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
                    : () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF3048),
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                ),
                minimumSize: const Size(0, 44),
                textStyle: Theme.of(context).textTheme.bodyLarge!
                    .copyWith(fontWeight: FontWeight.w500),
              ),
              onPressed: _isLoading
                  ? null
                  : () =>
                        Navigator.pushNamed(context, AppRoutes.forgotPassword),
              child: const Text('Forgot password?'),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            AuthStatusMessage.error(message: _errorMessage!),
          ],
          const SizedBox(height: 12),
          AuthButton(
            label: 'Sign in',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _login,
          ),
          const SizedBox(height: AppSpacing.md),
          AuthButton(
            label: 'Create an account',
            secondary: true,
            onPressed: _isLoading
                ? null
                : () => Navigator.pushNamed(context, AppRoutes.register),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    ),
  );
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Email is required.';
  }
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
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
