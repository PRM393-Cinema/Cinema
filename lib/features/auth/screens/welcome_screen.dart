import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/session/session_state.dart';
import '../../../core/widgets/app_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _onGuest(BuildContext context) {
    SessionProvider.of(context).setGuest();
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  void _onSignIn(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.login);
  }

  void _onCreateAccount(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.register);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.movie_creation_outlined,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.xxl),
              const Text(
                'Welcome to Cinema',
                style: AppTextStyles.display,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Your next movie experience starts here.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label: 'Continue as guest',
                onPressed: () => _onGuest(context),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.secondary(
                label: 'Sign in',
                onPressed: () => _onSignIn(context),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => _onCreateAccount(context),
                child: const Text(
                  'Create account',
                  style: AppTextStyles.button,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
