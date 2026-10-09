import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

class CinemaNavigationBar extends StatelessWidget {
  const CinemaNavigationBar({required this.selectedIndex, super.key});
  final int selectedIndex;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        AppColors.surfaceSoft.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.015),
                        AppColors.primary.withValues(alpha: 0.07),
                      ],
                      stops: const [0, 0.18, 0.72, 1],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: NavigationBarTheme(
                      data: NavigationBarTheme.of(context).copyWith(
                        indicatorShape: StadiumBorder(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 0.5,
                          ),
                        ),
                        labelTextStyle: WidgetStateProperty.resolveWith(
                          (states) => TextStyle(
                            color: states.contains(WidgetState.selected)
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        iconTheme: WidgetStateProperty.resolveWith(
                          (states) => IconThemeData(
                            color: states.contains(WidgetState.selected)
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                      child: NavigationBar(
                        height: 68,
                        selectedIndex: selectedIndex,
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        indicatorColor: AppColors.primary.withValues(
                          alpha: 0.18,
                        ),
                        onDestinationSelected: (index) {
                          if (index == selectedIndex) return;
                          Navigator.pushReplacementNamed(
                            context,
                            [
                              AppRoutes.home,
                              AppRoutes.myBookings,
                              AppRoutes.profile,
                            ][index],
                          );
                        },
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.movie_outlined),
                            selectedIcon: Icon(Icons.movie),
                            label: 'Home',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.confirmation_number_outlined),
                            selectedIcon: Icon(Icons.confirmation_number),
                            label: 'Tickets',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.person_outline),
                            selectedIcon: Icon(Icons.person),
                            label: 'Account',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class CinemaPanel extends StatelessWidget {
  const CinemaPanel({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.surfaceSoft, AppColors.surface],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}
