import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/cinema_background.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({
    required this.title,
    required this.child,
    required this.selectedIndex,
    this.staffMode = false,
    super.key,
  });

  final String title;
  final Widget child;
  final int selectedIndex;
  final bool staffMode;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _backgroundKey = GlobalKey();

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: CinemaGlassBackground(
      key: _backgroundKey,
      child: CinemaBackground(
        child: SafeArea(
          bottom: false,
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
                            widget.staffMode ? 'STAFF' : 'ADMIN',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(widget.title, style: AppTextStyles.heading1),
                  ],
                ),
              ),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: CinemaNavigationBar(
      selectedIndex: widget.selectedIndex,
      backgroundKey: _backgroundKey,
      destinations: widget.staffMode
          ? const [
              (
                'Dashboard',
                Icons.space_dashboard_rounded,
                AppRoutes.staffDashboard,
              ),
              ('Operations', Icons.local_activity, AppRoutes.staffOperations),
              ('Profile', Icons.person, AppRoutes.staffProfile),
            ]
          : const [
              (
                'Dashboard',
                Icons.space_dashboard_rounded,
                AppRoutes.adminDashboard,
              ),
              ('Accounts', Icons.manage_accounts, AppRoutes.adminUsers),
              ('Profile', Icons.person, AppRoutes.adminProfile),
            ],
    ),
  );
}
