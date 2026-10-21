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
import '../../../core/widgets/cinema_page.dart';
import '../../../data/repositories/auth_repository.dart';

// Shown in the customer app to staff and admin accounts: the cinema is
// managed from the admin website, on a computer.
class ManagementAccountScreen extends StatefulWidget {
  const ManagementAccountScreen({
    required this.authRepository,
    this.adminUrl,
    this.canCheckIn = false,
    super.key,
  });

  final AuthRepository authRepository;

  // Staff at the cinema entrance scan tickets with the phone camera.
  final bool canCheckIn;

  // Defaults to ApiConfig.adminUrl; tests pass their own.
  final String? adminUrl;

  @override
  State<ManagementAccountScreen> createState() =>
      _ManagementAccountScreenState();
}

class _ManagementAccountScreenState extends State<ManagementAccountScreen> {
  bool _isSigningOut = false;

  String? get _adminUrl => widget.adminUrl ?? ApiConfig.adminUrl;

  Future<void> _openAdminSite(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_self',
    );
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    await widget.authRepository.logout();
    if (!mounted) return;
    SessionProvider.of(context).clear();
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final url = _adminUrl;

    return CinemaPage(
      title: 'CosmoQ Cinema',
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
                    Icons.admin_panel_settings_outlined,
                    color: AppColors.primary,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Use the admin website',
                    key: Key('managementAccountTitle'),
                    style: AppTextStyles.heading2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    url == null
                        ? 'Staff and admin accounts manage the cinema from the '
                              'admin website on a computer.'
                        : 'Staff and admin accounts manage the cinema from the '
                              'admin website on a computer:',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  if (url != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SelectableText(
                      url,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Open admin website',
                      leadingIcon: Icons.open_in_new,
                      useGradient: true,
                      onPressed: _isSigningOut
                          ? null
                          : () => _openAdminSite(url),
                    ),
                  ],
                  if (widget.canCheckIn) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      key: const Key('openCheckIn'),
                      label: 'Check in tickets',
                      leadingIcon: Icons.qr_code_scanner,
                      useGradient: url == null,
                      onPressed: _isSigningOut
                          ? null
                          : () => Navigator.pushNamed(
                              context,
                              AppRoutes.staffCheckIn,
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
    );
  }
}
