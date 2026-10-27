import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/responsive_columns.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/auth_response.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../admin/widgets/admin_page.dart';
import '../../../data/models/loyalty.dart';
import '../../../data/repositories/booking_repository.dart';
import '../widgets/membership_card.dart';

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
    if (widget.adminMode || widget.staffMode) {
      return AdminPage(
        title: widget.staffMode ? 'Staff profile' : 'Admin profile',
        section: AdminSection.profile,
        child: Builder(builder: _buildBody),
      );
    }
    return Scaffold(
      extendBody: true,
      body: CinemaGlassBackground(
        key: _glassBackgroundKey,
        child: CinemaBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: pagePadding(context, AppSpacing.lg),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Account settings',
                      style: AppTextStyles.heading2,
                    ),
                  ),
                ),
                Expanded(child: Builder(builder: _buildBody)),
              ],
            ),
          ),
        ),
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

    final identity = <Widget>[
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
    ];
    final card = _card;
    final details = <Widget>[
      if (card != null) ...[
        MembershipCard(card: card),
        const SizedBox(height: AppSpacing.xl),
      ],
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
    ];
    final buttons = <Widget>[
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
      if (!widget.adminMode && !widget.staffMode) ...[
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
          onPressed: () => Navigator.pushNamed(context, AppRoutes.myBookings),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton.secondary(
          label: 'Notifications',
          leadingIcon: Icons.notifications_none_outlined,
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.notifications),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      AppButton.danger(
        label: 'Sign out',
        leadingIcon: Icons.logout,
        isLoading: _isLoggingOut,
        onPressed: _isLoggingOut ? null : _logout,
      ),
    ];

    return SingleChildScrollView(
      padding: pagePadding(
        context,
        AppSpacing.xl,
      ).copyWith(bottom: AppSpacing.xl + MediaQuery.paddingOf(context).bottom),
      child: isDesktopLayout(context)
          // Website: who is signed in and the account menu on the left, the
          // details on the right.
          ? ResponsiveColumns(
              sideOnLeft: true,
              sideWidth: 340,
              side: [
                CinemaPanel(
                  surfaceOpacity: 0.8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: identity,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ...buttons,
              ],
              main: details,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...identity,
                const SizedBox(height: AppSpacing.xl),
                ...details,
                const SizedBox(height: AppSpacing.xl),
                ...buttons,
              ],
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
      surfaceOpacity: 0.8,
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
