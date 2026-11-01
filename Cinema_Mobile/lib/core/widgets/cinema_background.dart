import 'dart:math' as math;
import 'dart:ui' show Tangent;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class CinemaBackground extends StatelessWidget {
  const CinemaBackground({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    // The desktop frame paints one continuous backdrop behind its header and pages.
    if (context.findAncestorWidgetOfExactType<CinemaBackground>() != null) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.28 + 0.72 * AppPalette.of(context).lightness,
                child: ClipRect(
                  child: CustomPaint(
                    painter: CinemaBackdrop(
                      colors: AppPalette.of(context),
                      logoCenter: Offset(constraints.maxWidth / 2, 72),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class CinemaBackdrop extends CustomPainter {
  const CinemaBackdrop({
    required this.logoCenter,
    this.colors = const AppPalette(isLight: false),
  });

  final Offset logoCenter;
  final AppPalette colors;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = colors.background);
    if (colors.lightness < 1) {
      canvas.saveLayer(
        bounds,
        Paint()..color = Colors.white.withValues(alpha: 1 - colors.lightness),
      );
      _paintDark(canvas, size);
      canvas.restore();
    }
    if (colors.lightness > 0) {
      canvas.saveLayer(
        bounds,
        Paint()..color = Colors.white.withValues(alpha: colors.lightness),
      );
      _paintLight(canvas, size);
      canvas.restore();
    }
  }

  void _paintLight(Canvas canvas, Size size) {
    const motifs = [
      (Icons.movie_creation_outlined, 0.05, 0.19, -0.18),
      (Icons.local_movies_outlined, 0.94, 0.12, 0.18),
      (Icons.confirmation_number_outlined, 0.08, 0.52, -0.22),
      (Icons.videocam_outlined, 0.93, 0.58, 0.15),
      (Icons.theaters_outlined, 0.16, 0.87, 0.12),
      (Icons.movie_filter_outlined, 0.84, 0.91, -0.14),
    ];
    final iconSize = size.width < 600 ? 44.0 : 72.0;
    for (final (icon, x, y, angle) in motifs) {
      final text = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: iconSize,
            color: colors.primary.withValues(alpha: 0.14),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas
        ..save()
        ..translate(size.width * x, size.height * y)
        ..rotate(angle);
      text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
      canvas.restore();
      text.dispose();
    }
  }

  void _paintDark(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.background, colors.background, colors.surface],
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
      colors.primary.withValues(alpha: 0.56),
    );
    _paintStage(canvas, size);
  }

  void _paintFilmStrip(Canvas canvas, Size size) {
    // A web page loaded in a hidden tab can be 0 px wide: the ribbon then has
    // no length to place film holes along.
    if (size.width <= 0) return;
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
        ..color = colors.primary.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ribbonWidth + 1.5
        ..color = colors.primary.withValues(alpha: 0.75),
    );
    canvas.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ribbonWidth
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surfaceSoft, colors.background, colors.surfaceSoft],
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
          ..color = colors.border
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
      canvas.drawRRect(hole, Paint()..color = colors.background);
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
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, colors.background],
        ).createShader(stageArea),
    );
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.91),
        width: size.width * 1.05,
        height: size.height * 0.16,
      ),
      colors.primary.withValues(alpha: 0.33),
    );
    for (final x in [0.06, 0.94]) {
      _paintGlow(
        canvas,
        Rect.fromCenter(
          center: Offset(size.width * x, size.height * 0.86),
          width: size.width * 0.13,
          height: size.height * 0.22,
        ),
        colors.primary.withValues(alpha: 0.46),
      );
      _paintGlow(
        canvas,
        Rect.fromCenter(
          center: Offset(size.width * x, size.height * 0.9),
          width: size.width * 0.28,
          height: size.height * 0.035,
        ),
        colors.primary.withValues(alpha: 0.75),
      );
    }
    _paintGlow(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.892),
        width: size.width * 0.48,
        height: size.height * 0.05,
      ),
      colors.primary.withValues(alpha: 0.58),
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
        ..color = colors.primary.withValues(alpha: 0.44)
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
  bool shouldRepaint(covariant CinemaBackdrop oldDelegate) =>
      oldDelegate.logoCenter != logoCenter ||
      oldDelegate.colors.lightness != colors.lightness;
}
