import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_config.dart';
import '../../../core/session/session_state.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../data/repositories/auth_repository.dart';

// Admin website, signed in with a customer account: point the customer to
// the cinema website.
class StaffOnlyScreen extends StatefulWidget {
  const StaffOnlyScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<StaffOnlyScreen> createState() => _StaffOnlyScreenState();
}

class _StaffOnlyScreenState extends State<StaffOnlyScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    await widget.authRepository.logout();
    if (!mounted) return;
    SessionProvider.of(context).clear();
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final customerUrl = ApiConfig.customerUrl;

    return Scaffold(
      body: CinemaBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: CinemaPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      color: AppColors.primary,
                      size: 48,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'This website is for cinema staff',
                      key: Key('staffOnlyTitle'),
                      style: AppTextStyles.heading2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Customer accounts book tickets on the CosmoQ Cinema '
                      'website or app.',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    if (customerUrl != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Go to CosmoQ Cinema',
                        leadingIcon: Icons.open_in_new,
                        useGradient: true,
                        onPressed: _isSigningOut
                            ? null
                            : () => launchUrl(
                                Uri.parse(customerUrl),
                                webOnlyWindowName: '_self',
                              ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AppButton.secondary(
                      label: 'Sign out',
                      leadingIcon: Icons.logout,
                      isLoading: _isSigningOut,
                      onPressed: _isSigningOut ? null : _signOut,
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
