import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../core/widgets/cinema_page.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/auth_response.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../admin/widgets/admin_page.dart';
import '../../../data/models/loyalty.dart';
import '../../../data/repositories/booking_repository.dart';
import '../widgets/membership_card.dart';
import '../widgets/account_dialogs.dart';
import '../../../core/widgets/top_notice.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.authRepository,
    this.bookingRepository,
    this.adminMode = false,
    this.staffMode = false,
    super.key,
  });

  final AuthRepository authRepository;

  // Customers: loads the membership card (points and tier).
  final BookingRepository? bookingRepository;
  final bool adminMode;
  final bool staffMode;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _glassBackgroundKey = GlobalKey();
  AuthUser? _user;
  bool _hasStarted = false;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  String? _errorMessage;
  LoyaltyCard? _card;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStarted) {
      _hasStarted = true;
      _user = SessionProvider.of(context).user;
      _loadProfile();
      _loadCard();
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

  Future<void> _loadCard() async {
    final bookings = widget.bookingRepository;
    if (bookings == null || widget.adminMode || widget.staffMode) return;
    try {
      final card = await bookings.getMyLoyalty();
      if (mounted) setState(() => _card = card);
    } on Object {
      // The profile still shows without the card.
    }
  }

  Future<void> _editProfile(AuthUser user) async {
    final saved = await showDialog<AuthUser>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          EditProfileDialog(repository: widget.authRepository, user: user),
    );
    if (saved == null || !mounted) return;
    SessionProvider.of(context).setAuthenticated(saved);
    setState(() => _user = saved);
    showTopNotice(Overlay.of(context, rootOverlay: true), 'Profile saved.');
  }

  Future<void> _changePassword(AuthUser user) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangePasswordDialog(
        repository: widget.authRepository,
        onForgotPassword: () {
          Navigator.pop(dialogContext);
          Navigator.pushNamed(
            context,
            AppRoutes.forgotPassword,
            arguments: user.email,
          );
        },
      ),
    );
    if (changed == true && mounted) {
      showTopNotice(
        Overlay.of(context, rootOverlay: true),
        'Password changed. Other devices were signed out.',
      );
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
        backgroundColor: AppPalette.of(context).surface,
        title: const Text('Sign out?', style: AppTextStyles.title),
        content: const Text(
          'You can sign in again at any time.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Stay signed in',
              style: TextStyle(color: AppPalette.of(context).textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Sign out',
              style: TextStyle(color: AppPalette.of(context).error),
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
    if (widget.adminMode || widget.staffMode) {
      return AdminPage(
        title: widget.staffMode ? 'Staff profile' : 'Admin profile',
        section: AdminSection.profile,
        child: Builder(builder: _buildBody),
      );
    }
    final content = SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: pagePadding(context, AppSpacing.lg),
            child: const CinemaPageHeader(title: 'Account settings'),
          ),
          Expanded(child: Builder(builder: _buildBody)),
        ],
      ),
    );
    return Scaffold(
      extendBody: true,
      body: CinemaGlassBackground(
        key: _glassBackgroundKey,
        child: CinemaBackground(child: content),
      ),
      // The website has its navigation at the top.
      bottomNavigationBar: isDesktopLayout(context)
          ? null
          : CinemaNavigationBar(
              selectedIndex: 2,
              backgroundKey: _glassBackgroundKey,
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
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

    return _buildSettings(context, user);
  }

  Widget _buildSettings(BuildContext context, AuthUser user) {
    final colors = AppPalette.of(context);
    final desktop = isDesktopLayout(context);
    final sidebar = CinemaPanel(
      key: const Key('accountSettingsSidebar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                foregroundColor: colors.primary,
                child: Text(user.displayName.substring(0, 1).toUpperCase()),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SelectableText(
                      user.email,
                      style: AppTextStyles.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1, color: colors.border),
          ),
          Semantics(
            selected: true,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 18, color: colors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Overview',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _settingsLink(
            key: const Key('editProfile'),
            label: 'Edit profile',
            icon: Icons.edit_outlined,
            onPressed: () => _editProfile(user),
          ),
          _settingsLink(
            key: const Key('changePassword'),
            label: 'Change password',
            icon: Icons.lock_outline,
            onPressed: () => _changePassword(user),
          ),
          if (!widget.adminMode && !widget.staffMode) ...[
            _settingsLink(
              label: 'Payment history',
              icon: Icons.receipt_long_outlined,
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.paymentHistory),
            ),
            _settingsLink(
              label: 'My bookings',
              icon: Icons.confirmation_number_outlined,
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.myBookings),
            ),
            _settingsLink(
              label: 'Notifications',
              icon: Icons.notifications_none_outlined,
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.notifications),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1, color: colors.border),
          ),
          _settingsLink(
            label: _isLoggingOut ? 'Signing out...' : 'Sign out',
            icon: Icons.logout,
            color: colors.error,
            onPressed: _isLoggingOut ? null : _logout,
          ),
        ],
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        if (_card != null) ...[
          const SizedBox(height: AppSpacing.lg),
          MembershipCard(
            card: _card!,
            compact: true,
            onHistory: () =>
                Navigator.pushNamed(context, AppRoutes.pointHistory),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Showing saved details: $_errorMessage',
            style: AppTextStyles.caption,
          ),
        ],
      ],
    );
    return SingleChildScrollView(
      padding: pagePadding(
        context,
        AppSpacing.lg,
      ).copyWith(bottom: AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
      child: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 240, child: sidebar),
                const SizedBox(width: AppSpacing.xl),
                Expanded(child: details),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sidebar,
                const SizedBox(height: AppSpacing.lg),
                details,
              ],
            ),
    );
  }

  Widget _settingsLink({
    Key? key,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
  }) => TextButton(
    key: key,
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: color ?? AppPalette.of(context).textPrimary,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(AppSpacing.sm),
      minimumSize: const Size(0, 44),
      visualDensity: VisualDensity.standard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(label)),
      ],
    ),
  );

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
    final colors = AppPalette.of(context);
    return CinemaPanel(
      key: const Key('accountProfileGrid'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('My profile', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = isDesktopLayout(context) ? 2 : 1;
              final width =
                  (constraints.maxWidth - AppSpacing.lg * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: [
                  for (final (label, value) in rows)
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: AppTextStyles.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          SelectableText(
                            value,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
