import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/layout.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({
    required this.title,
    required this.child,
    required this.selectedIndex,
    super.key,
  });

  final String title;
  final Widget child;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: centeredPadding(context, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'COSMOQ',
                      style: AppTextStyles.title.copyWith(
                        color: AppColors.primary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ADMIN',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(title, style: AppTextStyles.heading1),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: selectedIndex,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.16),
      onDestinationSelected: (index) {
        final destination = [
          AppRoutes.adminDashboard,
          AppRoutes.adminUsers,
          AppRoutes.adminProfile,
        ][index];
        if (ModalRoute.of(context)?.settings.name == destination) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          destination,
          (route) =>
              index != 0 && route.settings.name == AppRoutes.adminDashboard,
        );
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.space_dashboard_outlined),
          selectedIcon: Icon(
            Icons.space_dashboard_rounded,
            color: AppColors.primary,
          ),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.manage_accounts_outlined),
          selectedIcon: Icon(Icons.manage_accounts, color: AppColors.primary),
          label: 'Accounts',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: AppColors.primary),
          label: 'Profile',
        ),
      ],
    ),
  );
}
