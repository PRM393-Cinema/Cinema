import 'dart:math' as math;
import 'dart:ui' show Tangent;

import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.backToHome = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool backToHome;

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
      prefixIconColor: const Color(0xFFD3D9E7),
      hintStyle: AppTextStyles.body.copyWith(color: const Color(0xFF929DB4)),
      labelStyle: AppTextStyles.body.copyWith(color: const Color(0xFF9DA4BA)),
      floatingLabelStyle: AppTextStyles.caption.copyWith(
        color: const Color(0xFFFF5363),
      ),
      border: _glassBorder(Colors.white.withValues(alpha: 0.22)),
      enabledBorder: _glassBorder(Colors.white.withValues(alpha: 0.24)),
      disabledBorder: _glassBorder(Colors.white.withValues(alpha: 0.12)),
      focusedBorder: _glassBorder(AppColors.primary),
      errorBorder: _glassBorder(AppColors.error),
      focusedErrorBorder: _glassBorder(AppColors.error),
    );
    return Scaffold(
      backgroundColor: const Color(0xFF030716),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topSpace =
                (constraints.maxHeight * (backToHome ? 0.16 : 0.075))
                    .clamp(64.0, backToHome ? 152.0 : 80.0)
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
                          topSpace + (backToHome ? 36 : 28),
                        ),
                      ),
                    ),
                  ),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    inputDecorationTheme: fieldTheme,
                    progressIndicatorTheme: const ProgressIndicatorThemeData(
                      color: Colors.white,
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(gutter, topSpace, gutter, 40),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _BrandMark(compact: !backToHome),
                            const SizedBox(height: 20),
                            Center(
                              child: Container(
                                width: 24,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF2441),
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
                              style: AppTextStyles.heading1.copyWith(
                                fontSize: backToHome ? 28 : 26,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              subtitle,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: const Color(0xFF929DB4),
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
                Positioned(
                  top: 8,
                  left: gutter - 8,
                  child: Tooltip(
                    message: backToHome ? 'Back to home' : 'Back',
                    child: TextButton.icon(
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      label: Text(backToHome ? 'Home' : 'Back'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () {
                        if (backToHome) {
                          final navigator = Navigator.of(context);
                          var foundHome = false;
                          navigator.popUntil((route) {
                            foundHome = route.settings.name == AppRoutes.home;
                            return foundHome || route.isFirst;
                          });
                          if (!foundHome) {
                            navigator.pushReplacementNamed(AppRoutes.home);
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
        colors: [Color(0xFF1E2230), Color(0xFF141927), Color(0xFF291C2B)],
        stops: [0, 0.7, 1],
      ),
    ),
    child: child,
  );
}

class AuthButton extends StatelessWidget {
  const AuthButton({
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.secondary = false,
    super.key,
  });

  const AuthButton.secondary({
    required this.label,
    this.onPressed,
    this.isLoading = false,
    super.key,
  }) : secondary = true;

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    final disabled = onPressed == null && !isLoading;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: secondary
                ? const [Color(0xFF171A29), Color(0xFF141522)]
                : const [Color(0xFFF01634), Color(0xFFCA0025)],
          ),
          border: Border.all(
            color: secondary
                ? Colors.white.withValues(alpha: 0.24)
                : const Color(0xFFFF3049),
            width: secondary ? 1 : 1.2,
          ),
          boxShadow: secondary
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFFFF1436).withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: AppButton(
            label: label,
            isLoading: isLoading,
            onPressed: onPressed,
            variant: secondary
                ? AppButtonVariant.secondary
                : AppButtonVariant.primary,
            trailingIcon: secondary ? null : Icons.arrow_forward_rounded,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
              shadowColor: Colors.transparent,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: radius),
              textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
                fontSize: secondary ? 16 : 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
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
              colors: [Color(0xFF271726), Color(0xFF080D1A)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF183B).withValues(alpha: 0.28),
                blurRadius: 32,
                spreadRadius: 3,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Icon(
            Icons.local_movies_outlined,
            color: Color(0xFFFF243B),
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

class AuthStatusMessage extends StatelessWidget {
  const AuthStatusMessage._({
    required this.message,
    required this.color,
    required this.icon,
  });

  const AuthStatusMessage.error({required String message})
    : this._(
        message: message,
        color: AppColors.error,
        icon: Icons.error_outline,
      );

  const AuthStatusMessage.success({required String message})
    : this._(
        message: message,
        color: AppColors.success,
        icon: Icons.check_circle_outline,
      );

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.borderRadiusMd,
          border: Border.all(color: color),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: AppSpacing.xl),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
          colors: [Color(0xFF050B19), Color(0xFF020612), Color(0xFF050918)],
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
      const Color(0x90FF1435),
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
        ..color = const Color(0x80F01536)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ribbonWidth + 1.5
        ..color = const Color(0xBFFF2542),
    );
    canvas.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ribbonWidth
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241525), Color(0xFF0A0E1B), Color(0xFF221527)],
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
          ..color = const Color(0xFF343042)
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
      canvas.drawRRect(hole, Paint()..color = const Color(0xFF030611));
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
          colors: [Color(0x00030716), Color(0xCC030716)],
        ).createShader(stageArea),
    );
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.91),
        width: size.width * 1.05,
        height: size.height * 0.16,
      ),
      const Color(0x55E5092D),
    );
    for (final x in [0.06, 0.94]) {
      _paintGlow(
        canvas,
        Rect.fromCenter(
          center: Offset(size.width * x, size.height * 0.86),
          width: size.width * 0.13,
          height: size.height * 0.22,
        ),
        const Color(0x75FF1238),
      );
      _paintGlow(
        canvas,
        Rect.fromCenter(
          center: Offset(size.width * x, size.height * 0.9),
          width: size.width * 0.28,
          height: size.height * 0.035,
        ),
        const Color(0xC0FF2441),
      );
    }
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.892),
        width: size.width * 0.48,
        height: size.height * 0.05,
      ),
      const Color(0x95FF1640),
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
        ..color = const Color(0x70FF1A3D)
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
  bool shouldRepaint(covariant _CinemaBackdrop oldDelegate) => true;
}
