import 'dart:async';
import 'dart:ui';

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

      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Login successful',
        barrierColor: Colors.black.withValues(alpha: 0.72),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, _, _) => const Material(
          type: MaterialType.transparency,
          child: _LoginSuccessDialog(),
        ),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );
      if (!mounted) return;

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

  Future<void> _openForgotPassword() async {
    final email = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Forgot password',
      barrierColor: Colors.black.withValues(alpha: 0.76),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, _) => Material(
        type: MaterialType.transparency,
        child: _ForgotPasswordDialog(authRepository: widget.authRepository),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );

    if (!mounted || email == null) return;
    Navigator.pushNamed(context, AppRoutes.resetPassword, arguments: email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
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
                        const _AuthTitle(
                          key: Key('loginTitle'),
                          first: 'LOGIN TO ',
                          accent: 'CINEMA',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Welcome back! Access your booking account',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        AppTextField(
                          key: const Key('loginEmailField'),
                          label: 'Email',
                          labelAbove: true,
                          hint: 'johndoe@example.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_isLoading,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          key: const Key('loginPasswordField'),
                          label: 'Password',
                          labelAbove: true,
                          labelAction: TextButton(
                            onPressed: _isLoading ? null : _openForgotPassword,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: AppColors.primary,
                              textStyle: AppTextStyles.caption,
                            ),
                            child: const Text('Forgot password?'),
                          ),
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
                          _LoginError(message: _errorMessage!),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: 'LOG IN',
                          useGradient: true,
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _login,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: AppTextStyles.caption,
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.register,
                                    ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: AppColors.primary,
                                textStyle: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('Register here'),
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

class _AuthTitle extends StatelessWidget {
  const _AuthTitle({super.key, required this.first, required this.accent});

  final String first;
  final String accent;

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
        children: [
          TextSpan(text: first),
          TextSpan(
            text: accent,
            style: const TextStyle(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _LoginSuccessDialog extends StatefulWidget {
  const _LoginSuccessDialog();

  @override
  State<_LoginSuccessDialog> createState() => _LoginSuccessDialogState();
}

class _LoginSuccessDialogState extends State<_LoginSuccessDialog> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.xl),
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  blurRadius: 28,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.12),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Authenticated!',
                  style: AppTextStyles.heading2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Login successful.',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Redirecting to your cinema...',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.authRepository.forgotPassword(
        email: _emailController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(response.email);
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
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.xl),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withValues(alpha: 0.1),
                            border: Border.all(color: AppColors.accent),
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.accent,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Text(
                        'Quên Mật Khẩu?',
                        style: AppTextStyles.title,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Nhập email đã đăng ký, chúng tôi sẽ gửi liên kết đặt lại mật khẩu (hết hạn sau 15 phút).',
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        key: const Key('forgotEmailField'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        decoration: const InputDecoration(
                          hintText: 'you@example.com',
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Email is required.';
                          if (!email.contains('@')) {
                            return 'Please enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _errorMessage!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _ForgotPasswordButton(
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _submit,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -AppSpacing.md,
                  right: -AppSpacing.md,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordButton extends StatelessWidget {
  const _ForgotPasswordButton({required this.isLoading, this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.xxxl,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accent, Color(0xFFF59E0B)],
          ),
          borderRadius: AppRadius.borderRadiusMd,
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.surfaceSoft,
            disabledForegroundColor: AppColors.textSecondary,
            shadowColor: Colors.transparent,
            elevation: 0,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderRadiusMd,
            ),
            textStyle: AppTextStyles.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          child: isLoading
              ? const SizedBox.square(
                  dimension: AppSpacing.xl,
                  child: CircularProgressIndicator(
                    strokeWidth: AppSpacing.xs,
                    color: Colors.white,
                  ),
                )
              : const Text('GỬI LIÊN KẾT ĐẶT LẠI'),
        ),
      ),
    );
  }
}
