import 'dart:math' as math;
import 'dart:ui' show Tangent;

import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
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
    this.showBack = true,
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
                          painter: _CinemaBackdrop(
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

class _CinemaBackdrop extends CustomPainter {
  const _CinemaBackdrop({required this.logoCenter});

  final Offset logoCenter;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.background,
            AppColors.background,
            AppColors.surface,
          ],
          stops: [0, 0.62, 1],
        ).createShader(Offset.zero & size),
    );

    _paintFilmStrip(canvas, size);
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: logoCenter - const Offset(0, 26),
        width: size.width * 0.5,
        height: size.width * 0.42,
      ),
      AppColors.primary.withValues(alpha: 0.56),
    );
    _paintStage(canvas, size);
  }

  void _paintFilmStrip(Canvas canvas, Size size) {
    final ribbon = Path()
      ..moveTo(-size.width * 0.14, logoCenter.dy - size.width * 0.3)
      ..cubicTo(
        size.width * 0.24,
        logoCenter.dy - size.width * 0.2,
        size.width * 0.69,
        logoCenter.dy + size.width * 0.15,
        size.width * 1.14,
        logoCenter.dy + size.width * 0.27,
      );
    final ribbonWidth = math.min(size.width * 0.18, 96.0).toDouble();
    final filmBounds = Rect.fromLTRB(
      0,
      logoCenter.dy - size.width * 0.5,
      size.width,
      logoCenter.dy + size.width * 0.5,
    );
    canvas.saveLayer(filmBounds, Paint());
    canvas.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ribbonWidth + 6
        ..color = AppColors.primary.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ribbonWidth + 1.5
        ..color = AppColors.primary.withValues(alpha: 0.75),
    );
    canvas.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ribbonWidth
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceSoft,
            AppColors.background,
            AppColors.surfaceSoft,
          ],
        ).createShader(filmBounds),
    );
    final metric = ribbon.computeMetrics().first;
    for (var distance = 12.0; distance < metric.length - 8; distance += 18) {
      _paintFilmHoles(
        canvas,
        metric.getTangentForOffset(distance)!,
        ribbonWidth,
      );
    }
    for (var distance = 28.0; distance < metric.length - 12; distance += 44) {
      final tangent = metric.getTangentForOffset(distance)!;
      final angle = math.atan2(tangent.vector.dy, tangent.vector.dx);
      final normal = Offset(-math.sin(angle), math.cos(angle));
      canvas.drawLine(
        tangent.position - normal * (ribbonWidth * 0.29),
        tangent.position + normal * (ribbonWidth * 0.29),
        Paint()
          ..color = AppColors.border
          ..strokeWidth = 3,
      );
    }
    // Fade the complete film layer, including its perforations, behind the logo.
    canvas.drawRect(
      filmBounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          colors: [
            Colors.white,
            Colors.white,
            Colors.transparent,
            Colors.transparent,
            Colors.white,
            Colors.white,
          ],
          stops: [0, 0.08, 0.4, 0.6, 0.92, 1],
        ).createShader(filmBounds),
    );
    canvas.restore();
  }

  void _paintFilmHoles(Canvas canvas, Tangent tangent, double ribbonWidth) {
    final angle = math.atan2(tangent.vector.dy, tangent.vector.dx);
    final normal = Offset(-math.sin(angle), math.cos(angle));
    for (final side in [-1.0, 1.0]) {
      final position = tangent.position + normal * (ribbonWidth * 0.35 * side);
      canvas
        ..save()
        ..translate(position.dx, position.dy)
        ..rotate(angle);
      final hole = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 9, height: 5),
        const Radius.circular(0.6),
      );
      canvas.drawRRect(hole, Paint()..color = AppColors.background);
      canvas.drawRRect(
        hole,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = Colors.white.withValues(alpha: 0.08),
      );
      canvas.restore();
    }
  }

  void _paintStage(Canvas canvas, Size size) {
    final stageArea = Rect.fromLTWH(
      0,
      size.height * 0.76,
      size.width,
      size.height * 0.24,
    );
    canvas.drawRect(
      stageArea,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, AppColors.background],
        ).createShader(stageArea),
    );
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.91),
        width: size.width * 1.05,
        height: size.height * 0.16,
      ),
      AppColors.primary.withValues(alpha: 0.33),
    );
    for (final x in [0.06, 0.94]) {
      _paintGlow(
        canvas,
        Rect.fromCenter(
          center: Offset(size.width * x, size.height * 0.86),
          width: size.width * 0.13,
          height: size.height * 0.22,
        ),
        AppColors.primary.withValues(alpha: 0.46),
      );
      _paintGlow(
        canvas,
        Rect.fromCenter(
          center: Offset(size.width * x, size.height * 0.9),
          width: size.width * 0.28,
          height: size.height * 0.035,
        ),
        AppColors.primary.withValues(alpha: 0.75),
      );
    }
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.892),
        width: size.width * 0.48,
        height: size.height * 0.05,
      ),
      AppColors.primary.withValues(alpha: 0.58),
    );
    final horizon = Path()
      ..moveTo(0, size.height * 0.905)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.86,
        size.width,
        size.height * 0.905,
      );
    canvas.drawPath(
      horizon,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.primary.withValues(alpha: 0.44)
        ..strokeWidth = 1.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _paintGlow(Canvas canvas, Rect bounds, Color color) {
    const unit = Rect.fromLTWH(0, 0, 1, 1);
    canvas
      ..save()
      ..translate(bounds.left, bounds.top)
      ..scale(bounds.width, bounds.height);
    canvas.drawOval(
      unit,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color,
            color.withValues(alpha: color.a * 0.25),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(unit),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CinemaBackdrop oldDelegate) =>
      oldDelegate.logoCenter != logoCenter;
}
