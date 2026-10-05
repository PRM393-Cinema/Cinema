import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import 'session_state.dart';

abstract final class AuthGuard {
  static void requireAuthentication(
    BuildContext context, {
    required VoidCallback onAuthenticated,
    String? pendingRoute,
    Object? pendingArguments,
  }) {
    final session = SessionProvider.of(context);
    if (session.isAuthenticated) {
      onAuthenticated();
      return;
    }

    _showSignInRequiredDialog(context, pendingRoute, pendingArguments);
  }

  static void _showSignInRequiredDialog(
    BuildContext context,
    String? pendingRoute,
    Object? pendingArguments,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sign in required',
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Please sign in to continue with this action.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: 'Sign in',
                  onPressed: () {
                    Navigator.of(bottomSheetContext).pop();
                    _navigateToLogin(context, pendingRoute, pendingArguments);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton.secondary(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(bottomSheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _navigateToLogin(BuildContext context, String? pendingRoute, Object? pendingArguments) {
    Navigator.of(context).pushNamed(
      AppRoutes.login,
      arguments: {
        'pendingRoute': pendingRoute,
        'pendingArguments': pendingArguments,
      },
    );
  }
}
