import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';

class AuthSuccessDialog extends StatefulWidget {
  const AuthSuccessDialog({
    required this.title,
    required this.message,
    required this.footer,
    super.key,
  });

  final String title;
  final String message;
  final String footer;

  @override
  State<AuthSuccessDialog> createState() => _AuthSuccessDialogState();
}

class _AuthSuccessDialogState extends State<AuthSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  Timer? _dismissTimer;
  Animation<double>? _entrance;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion) {
      _animation.stop();
      _animation.value = 1;
    }
    if (_started) return;
    _entrance?.removeStatusListener(_onEntranceStatus);
    _entrance = ModalRoute.of(context)?.animation;
    if (_entrance == null || _entrance!.isCompleted) {
      _onEntranceStatus(AnimationStatus.completed);
    } else {
      _entrance!.addStatusListener(_onEntranceStatus);
    }
  }

  void _onEntranceStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // Let the fully visible dialog paint before drawing the first arc.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSuccess());
  }

  Future<void> _startSuccess() async {
    if (!mounted || _started) return;
    _started = true;
    _entrance?.removeStatusListener(_onEntranceStatus);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion) {
      _animation.value = 1;
    } else {
      try {
        await _animation.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    _dismissTimer = Timer(
      Duration(milliseconds: reducedMotion ? 1600 : 1000),
      () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  void dispose() {
    _entrance?.removeStatusListener(_onEntranceStatus);
    _dismissTimer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.xl),
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.surfaceSoft, AppColors.background],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: CustomPaint(
                        painter: _SuccessCheckPainter(_animation),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      widget.title,
                      style: AppTextStyles.heading2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.message,
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      widget.footer,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SuccessCheckPainter extends CustomPainter {
  _SuccessCheckPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    assert(progress >= 0 && progress <= 1);
    double phase(double start, double end) =>
        ((progress - start) / (end - start)).clamp(0.0, 1.0);
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final pen = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(50, 50), radius: 40),
      -math.pi / 2,
      math.pi * 2 * phase(0, 0.45),
      false,
      pen,
    );
    final check = Path()
      ..moveTo(28, 51)
      ..lineTo(44, 66)
      ..lineTo(73, 35);
    final metric = check.computeMetrics().first;
    pen.strokeWidth = 4;
    canvas.drawPath(
      metric.extractPath(
        0,
        metric.length * Curves.easeOutCubic.transform(phase(0.5, 1)),
      ),
      pen,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SuccessCheckPainter oldDelegate) =>
      oldDelegate.animation != animation;
}
