import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.titleKey,
    this.showBack = false,
    this.backToHome = false,
    super.key,
  });

  final String title;
  final Key? titleKey;
  final String subtitle;
  final Widget child;
  final bool backToHome;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final fieldTheme = Theme.of(context).inputDecorationTheme.copyWith(
      filled: true,
      fillColor: Colors.transparent,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      prefixIconColor: AppColors.textPrimary,
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      labelStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      floatingLabelStyle: AppTextStyles.caption.copyWith(
        color: AppColors.primary,
      ),
      border: _glassBorder(Colors.white.withValues(alpha: 0.22)),
      enabledBorder: _glassBorder(Colors.white.withValues(alpha: 0.24)),
      disabledBorder: _glassBorder(Colors.white.withValues(alpha: 0.12)),
      focusedBorder: _glassBorder(AppColors.primary),
      errorBorder: _glassBorder(AppColors.error),
      focusedErrorBorder: _glassBorder(AppColors.error),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 560,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final topSpace = (constraints.maxHeight * 0.16)
                    .clamp(64.0, 152.0)
                    .toDouble();
                final gutter = (constraints.maxWidth * 0.06)
                    .clamp(20.0, 32.0)
                    .toDouble();
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: ClipRect(
                        child: CustomPaint(
                          painter: CinemaBackdrop(
                            logoCenter: Offset(
                              constraints.maxWidth / 2,
                              topSpace + 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: fieldTheme,
                        progressIndicatorTheme:
                            const ProgressIndicatorThemeData(
                              color: Colors.white,
                            ),
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          topSpace,
                          gutter,
                          40,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _BrandMark(compact: false),
                                const SizedBox(height: 20),
                                Center(
                                  child: Container(
                                    width: 24,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.7,
                                          ),
                                          blurRadius: 16,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  title,
                                  key: titleKey,
                                  style: AppTextStyles.heading1.copyWith(
                                    fontSize: 28,
                                    letterSpacing: -0.5,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  subtitle,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.xxl),
                                child,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showBack)
                      Positioned(
                        top: 8,
                        left: gutter - 8,
                        child: Tooltip(
                          message: backToHome ? 'Back to home' : 'Back',
                          child: TextButton.icon(
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                            ),
                            label: Text(backToHome ? 'Home' : 'Back'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: () {
                              if (backToHome) {
                                final navigator = Navigator.of(context);
                                var foundHome = false;
                                navigator.popUntil((route) {
                                  foundHome =
                                      route.settings.name == AppRoutes.home;
                                  return foundHome || route.isFirst;
                                });
                                if (!foundHome) {
                                  navigator.pushReplacementNamed(
                                    AppRoutes.home,
                                  );
                                }
                                return;
                              }
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                Navigator.pushReplacementNamed(
                                  context,
                                  AppRoutes.login,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

OutlineInputBorder _glassBorder(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppRadius.lg),
  borderSide: BorderSide(color: color, width: 1.2),
);

class AuthFieldSurface extends StatelessWidget {
  const AuthFieldSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.surfaceSoft,
          AppColors.surface,
          AppColors.surfaceSoft,
        ],
        stops: [0, 0.7, 1],
      ),
    ),
    child: child,
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: compact ? 56 : 72,
          height: compact ? 56 : 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surfaceSoft, AppColors.background],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 32,
                spreadRadius: 3,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Icon(
            Icons.local_movies_outlined,
            color: AppColors.primary,
            size: compact ? 34 : 44,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Cinema App',
          style: AppTextStyles.display.copyWith(
            fontSize: compact ? 28 : 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}
