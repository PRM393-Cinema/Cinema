import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/auth_response.dart';
import '../../../data/repositories/auth_repository.dart';
import '../widgets/admin_page.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({required this.repository, super.key});
  final AuthRepository repository;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<(String, int, IconData)>? _counts;
  List<AuthUser> _users = [];
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pages = await Future.wait([
        widget.repository.users(),
        widget.repository.users(enabled: true),
        widget.repository.users(enabled: false),
      ]);
      final roles = await widget.repository.roles();
      if (!mounted) return;
      setState(() {
        _counts = [
          ('Total accounts', pages[0].totalCount, Icons.people_outline),
          ('Active', pages[1].totalCount, Icons.verified_user_outlined),
          ('Locked', pages[2].totalCount, Icons.lock_outline),
          ('Roles', roles.length, Icons.admin_panel_settings_outlined),
        ];
        _users = pages[0].items.take(5).toList();
      });
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Unable to load dashboard. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Dashboard',
    selectedIndex: 0,
    child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: centeredPadding(context, AppSpacing.lg),
        children: [
          const Text('Account overview', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Manage access and keep your cinema team organized.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_loading)
            const LoadingState(message: 'Loading dashboard...')
          else if (_error != null)
            ErrorState(
              title: 'Unable to load dashboard',
              message: _error!,
              onRetry: _load,
            )
          else if (_counts != null) ...[
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final (label, count, icon) in _counts!)
                    SizedBox(
                      width: (constraints.maxWidth - AppSpacing.md) / 2,
                      child: CinemaPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, color: AppColors.primary),
                            const SizedBox(height: AppSpacing.md),
                            Text('$count', style: AppTextStyles.display),
                            const SizedBox(height: AppSpacing.xs),
                            Text(label, style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('Accounts at a glance', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            if (_users.isEmpty)
              const Text('No accounts found.', style: AppTextStyles.bodySmall),
            for (final user in _users)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: CinemaPanel(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      user.enabled
                          ? Icons.person_outline
                          : Icons.person_off_outlined,
                      color: user.enabled ? AppColors.primary : AppColors.error,
                    ),
                    title: Text(user.displayName, style: AppTextStyles.title),
                    subtitle: Text(user.email, style: AppTextStyles.bodySmall),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.pushNamed(
                        context,
                        AppRoutes.adminUser(user.userId),
                      );
                      if (mounted) _load();
                    },
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
