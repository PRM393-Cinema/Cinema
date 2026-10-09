import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/auth_response.dart';
import '../../../data/repositories/auth_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AuthUser? _user;
  bool _hasStarted = false;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStarted) {
      _hasStarted = true;
      _user = SessionProvider.of(context).user;
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = _user == null;
      _errorMessage = null;
    });

    try {
      final user = await widget.authRepository.currentUser();
      if (!mounted) return;
      SessionProvider.of(context).setAuthenticated(user);
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _showError(error.message);
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

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sign out?', style: AppTextStyles.title),
        content: const Text(
          'You can sign in again at any time.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Stay signed in',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    await widget.authRepository.logout();
    if (!mounted) return;

    SessionProvider.of(context).clear();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Account settings')),
      body: CinemaBackground(
        child: SafeArea(bottom: false, child: _buildBody()),
      ),
      bottomNavigationBar: const CinemaNavigationBar(selectedIndex: 2),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState(message: 'Loading profile...');
    }

    final user = _user;
    if (user == null) {
      return ErrorState(
        title: 'Unable to load your profile',
        message: _errorMessage ?? 'Please sign in again.',
        onRetry: _loadProfile,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(
        AppSpacing.xl,
      ).copyWith(bottom: AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.background,
                    child: Text(
                      user.displayName.substring(0, 1).toUpperCase(),
                      style: AppTextStyles.display,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                user.displayName,
                style: AppTextStyles.heading1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                user.email,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              _InfoCard(
                rows: [
                  ('Full name', user.displayName),
                  ('Email', user.email),
                  ('Phone', user.phone ?? 'Not provided'),
                  ('Email verified', user.emailVerified ? 'Yes' : 'No'),
                  ('Role', user.roles.map(_roleLabel).join(', ')),
                  ('Member since', formatDate(user.createdAt)),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Showing saved details: $_errorMessage',
                  style: AppTextStyles.caption,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton.secondary(
                label: 'Change password',
                leadingIcon: Icons.lock_outline,
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.forgotPassword,
                  arguments: user.email,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.secondary(
                label: 'Payment history',
                leadingIcon: Icons.receipt_long_outlined,
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.paymentHistory),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.secondary(
                label: 'My bookings',
                leadingIcon: Icons.confirmation_number_outlined,
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.myBookings),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.secondary(
                label: 'Notifications',
                leadingIcon: Icons.notifications_none_outlined,
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.notifications),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.danger(
                label: 'Sign out',
                leadingIcon: Icons.logout,
                isLoading: _isLoggingOut,
                onPressed: _isLoggingOut ? null : _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _roleLabel(String role) {
    return switch (role) {
      'ROLE_ADMIN' => 'Admin',
      'ROLE_STAFF' => 'Staff',
      'ROLE_CUSTOMER' => 'Customer',
      _ => role,
    };
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return CinemaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'My profile',
            style: AppTextStyles.title.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(value, style: AppTextStyles.body),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
