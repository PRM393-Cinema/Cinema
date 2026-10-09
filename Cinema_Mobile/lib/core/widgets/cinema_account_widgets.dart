import 'dart:math' as math;
import 'dart:ui' show FragmentProgram, FragmentShader, ImageFilter;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

// Capture the body separately so the web lens never samples its own controls.
class CinemaGlassBackground extends StatelessWidget {
  const CinemaGlassBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (_) {
          (context.findRenderObject() as _RenderGlassBackground?)?.onChanged
              ?.call();
          return false;
        },
        child: _GlassBackgroundBoundary(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: child,
          ),
        ),
      );
}

class _GlassBackgroundBoundary extends SingleChildRenderObjectWidget {
  const _GlassBackgroundBoundary({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlassBackground();
}

class _RenderGlassBackground extends RenderRepaintBoundary {
  VoidCallback? onChanged;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onChanged?.call();
  }

  Future<ui.Image>? capture(Rect bounds, double pixelRatio) {
    if (!attached || !hasSize || layer == null) return null;
    return (layer! as OffsetLayer).toImage(bounds, pixelRatio: pixelRatio);
  }
}

class CinemaNavigationBar extends StatefulWidget {
  const CinemaNavigationBar({
    required this.selectedIndex,
    this.backgroundKey,
    super.key,
  });
  final int selectedIndex;
  final GlobalKey? backgroundKey;

  @override
  State<CinemaNavigationBar> createState() => _CinemaNavigationBarState();
}

class _CinemaNavigationBarState extends State<CinemaNavigationBar>
    with TickerProviderStateMixin {
  static double? _lastIndicatorPosition;

  late final AnimationController _indicator;
  late final AnimationController _interaction;
  int? _pointerId;
  int? _pressedIndex;
  Offset _pointerOrigin = Offset.zero;
  Offset _touchPosition = const Offset(0.5, 0.5);
  Offset _dragOffset = Offset.zero;
  FragmentShader? _refractionShader;
  final _glassKey = GlobalKey();
  _RenderGlassBackground? _background;
  ui.Image? _backdropImage;
  bool _captureScheduled = false;
  bool _capturing = false;
  bool _captureAgain = false;
  bool _captureFailed = false;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    final start = _lastIndicatorPosition ?? widget.selectedIndex.toDouble();
    _indicator = AnimationController(
      vsync: this,
      value: start,
      lowerBound: 0,
      upperBound: 2,
    )..addListener(_rememberIndicatorPosition);
    _lastIndicatorPosition = start;
    _interaction = AnimationController.unbounded(vsync: this)
      ..addListener(_scheduleBackdropCapture);

    if (start != widget.selectedIndex.toDouble()) {
      _animateAfterFirstFrame(widget.selectedIndex);
    }
    _loadRefractionShader();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.of(context).disableAnimations;
    if (_disableAnimations) {
      _interaction.stop();
      _interaction.value = 0;
    }
    if (_disableAnimations && _indicator.value != widget.selectedIndex) {
      _indicator.stop();
      _indicator.value = widget.selectedIndex.toDouble();
    }
    _scheduleBackdropCapture();
  }

  @override
  void didUpdateWidget(covariant CinemaNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _animateAfterFirstFrame(widget.selectedIndex);
    }
    if (oldWidget.backgroundKey != widget.backgroundKey) {
      _background?.onChanged = null;
      _background = null;
      _captureFailed = false;
      _scheduleBackdropCapture();
    }
  }

  void _rememberIndicatorPosition() {
    _lastIndicatorPosition = _indicator.value;
  }

  void _animateAfterFirstFrame(int target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_disableAnimations) {
        _indicator.value = target.toDouble();
        return;
      }
      _indicator.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 460, damping: 34),
          _indicator.value,
          target.toDouble(),
          0,
        ),
      );
    });
  }

  Future<void> _loadRefractionShader() async {
    try {
      final program = await FragmentProgram.fromAsset(
        'shaders/liquid_refraction.frag',
      );
      final shader = program.fragmentShader();
      if (!mounted) {
        shader.dispose();
        return;
      }
      setState(() => _refractionShader = shader);
      _scheduleBackdropCapture();
    } catch (error) {
      debugPrint(
        'Liquid glass shader unavailable; using the glass fallback: $error',
      );
    }
  }

  void _scheduleBackdropCapture() {
    if (!mounted ||
        ImageFilter.isShaderFilterSupported ||
        widget.backgroundKey == null ||
        _captureFailed) {
      return;
    }
    if (_capturing) {
      _captureAgain = true;
      return;
    }
    if (_captureScheduled) return;
    _captureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureScheduled = false;
      if (mounted) _captureBackdrop();
    });
  }

  Future<void> _captureBackdrop() async {
    final source = widget.backgroundKey?.currentContext?.findRenderObject();
    final glass = _glassKey.currentContext?.findRenderObject();
    if (source is! _RenderGlassBackground ||
        glass is! RenderBox ||
        !glass.hasSize) {
      return;
    }
    _background?.onChanged = null;
    _background = source..onChanged = _scheduleBackdropCapture;
    if (_refractionShader == null) return;
    _capturing = true;
    try {
      final origin = source.globalToLocal(glass.localToGlobal(Offset.zero));
      final bounds = (origin & glass.size).inflate(12);
      final image = await source.capture(
        bounds,
        math.min(MediaQuery.devicePixelRatioOf(context), 1.5),
      );
      if (image == null) return;
      if (!mounted) {
        image.dispose();
        return;
      }
      final previous = _backdropImage;
      setState(() => _backdropImage = image);
      WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
    } catch (error) {
      _captureFailed = true;
      if (mounted && _backdropImage != null) {
        final previous = _backdropImage;
        setState(() => _backdropImage = null);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => previous?.dispose(),
        );
      }
      debugPrint('Liquid glass capture unavailable; using fallback: $error');
    } finally {
      _capturing = false;
      if (_captureAgain) {
        _captureAgain = false;
        _scheduleBackdropCapture();
      }
    }
  }

  void _selectDestination(int index) {
    if (index == widget.selectedIndex) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      [AppRoutes.home, AppRoutes.myBookings, AppRoutes.profile][index],
      (route) => index != 0 && route.settings.name == AppRoutes.home,
    );
  }

  void _springPressure(double target) {
    if (_disableAnimations) return;
    _interaction.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 360, damping: 25),
        _interaction.value,
        target,
        _interaction.velocity,
      ),
    );
  }

  void _press(PointerDownEvent event) {
    if (_disableAnimations || _pointerId != null) return;
    final glass = _glassKey.currentContext?.findRenderObject();
    if (glass is! RenderBox || !glass.hasSize) return;
    final touch = _localTouch(event, glass);
    final index = (touch.dx * 3).floor().clamp(0, 2);
    setState(() {
      _pointerId = event.pointer;
      _pressedIndex = index;
      _pointerOrigin = event.position;
      _touchPosition = touch;
      _dragOffset = Offset.zero;
    });
    _springPressure(1);
  }

  Offset _localTouch(PointerEvent event, RenderBox glass) {
    final position = glass.globalToLocal(event.position);
    return Offset(
      (position.dx / glass.size.width).clamp(0.0, 1.0),
      (position.dy / glass.size.height).clamp(0.0, 1.0),
    );
  }

  void _drag(PointerMoveEvent event) {
    if (_pointerId != event.pointer || _disableAnimations) return;
    final glass = _glassKey.currentContext?.findRenderObject();
    if (glass is! RenderBox || !glass.hasSize) return;
    final delta = (event.position - _pointerOrigin) * 0.15;
    setState(() {
      _touchPosition = _localTouch(event, glass);
      _dragOffset = Offset(
        delta.dx.clamp(-5.0, 5.0),
        delta.dy.clamp(-6.0, 6.0),
      );
    });
    _scheduleBackdropCapture();
  }

  void _release(PointerEvent event) {
    if (_pointerId != event.pointer) return;
    _pointerId = null;
    _springPressure(0);
  }

  @override
  void dispose() {
    _background?.onChanged = null;
    _backdropImage?.dispose();
    _indicator.dispose();
    _interaction.dispose();
    _refractionShader?.dispose();
    super.dispose();
  }

  ImageFilter _backdropFilter(double width) {
    final diffusion = ImageFilter.blur(sigmaX: 2.4, sigmaY: 1.4);
    if (_refractionShader != null && ImageFilter.isShaderFilterSupported) {
      _refractionShader!
        ..setFloat(2, width)
        ..setFloat(3, 88)
        ..setFloat(4, 0)
        ..setFloat(5, 1)
        ..setFloat(6, _touchPosition.dx)
        ..setFloat(7, _interaction.value.clamp(0.0, 1.0))
        ..setFloat(8, _dragOffset.dy)
        ..setFloat(9, _touchPosition.dy);
      return ImageFilter.compose(
        outer: diffusion,
        inner: ImageFilter.shader(_refractionShader!),
      );
    }
    final centerX = width / 2;
    const centerY = 44.0;
    final lens =
        Matrix4.translationValues(centerX, centerY, 0) *
        (Matrix4.identity()
          ..setEntry(0, 0, 1.06)
          ..setEntry(1, 1, 1.16)) *
        Matrix4.translationValues(-centerX, -centerY, 0);
    return ImageFilter.compose(
      outer: diffusion,
      inner: ImageFilter.matrix(
        lens.storage,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _interaction,
    builder: (context, _) {
      final pressure = _interaction.value.clamp(0.0, 1.0);
      final deformation = _LiquidNavClipper(
        pressure: pressure,
        touch: _touchPosition,
        drag: _dragOffset,
      );
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5.5, 2, 5.5, 6),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 493),
              child: Listener(
                onPointerDown: _press,
                onPointerMove: _drag,
                onPointerUp: _release,
                onPointerCancel: _release,
                child: PhysicalShape(
                  clipper: deformation,
                  color: Colors.transparent,
                  shadowColor: Colors.black.withValues(alpha: 0.3),
                  elevation: 8,
                  clipBehavior: Clip.none,
                  child: RepaintBoundary(
                    key: _glassKey,
                    child: ClipPath(
                      clipper: deformation,
                      child: LayoutBuilder(
                        builder: (context, constraints) => BackdropFilter(
                          enabled: _backdropImage == null,
                          filter: _backdropFilter(constraints.maxWidth),
                          child: SizedBox(
                            height: 88,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_backdropImage != null &&
                                    _refractionShader != null)
                                  ImageFiltered(
                                    imageFilter: ImageFilter.blur(
                                      sigmaX: 2.4,
                                      sigmaY: 1.4,
                                    ),
                                    child: CustomPaint(
                                      painter: _GlassSnapshotPainter(
                                        shader: _refractionShader!,
                                        image: _backdropImage!,
                                        deformation: deformation,
                                      ),
                                    ),
                                  ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color.fromRGBO(255, 255, 255, 0.09),
                                        Color.fromRGBO(255, 255, 255, 0.02),
                                        Color.fromRGBO(5, 8, 16, 0.24),
                                        Color.fromRGBO(5, 8, 16, 0.27),
                                        Color.fromRGBO(255, 255, 255, 0.03),
                                      ],
                                      stops: [0, 0.18, 0.45, 0.8, 1],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.5,
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final slotWidth =
                                          constraints.maxWidth / 3;
                                      return Stack(
                                        children: [
                                          AnimatedBuilder(
                                            animation: _indicator,
                                            builder: (context, child) =>
                                                Positioned(
                                                  left:
                                                      _indicator.value
                                                              .clamp(0.0, 2.0)
                                                              .toDouble() *
                                                          slotWidth +
                                                      6,
                                                  top: 15,
                                                  bottom: 15,
                                                  width: slotWidth - 12,
                                                  child: child!,
                                                ),
                                            child: const _LiquidTabCapsule(),
                                          ),
                                          Row(
                                            children: [
                                              _destination(
                                                0,
                                                'Home',
                                                Icons.movie,
                                              ),
                                              _destination(
                                                1,
                                                'Tickets',
                                                Icons.confirmation_number,
                                              ),
                                              _destination(
                                                2,
                                                'Account',
                                                Icons.person,
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        painter: _LiquidGlassRimPainter(
                                          radius: 36,
                                          deformation: deformation,
                                        ),
                                      ),
                                    ),
                                  ),
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
        ),
      );
    },
  );

  Widget _destination(int index, String label, IconData icon) {
    final selected = widget.selectedIndex == index;
    return Expanded(
      child: Semantics(
        container: true,
        button: true,
        selected: selected,
        label: label,
        onTap: () => _selectDestination(index),
        child: ExcludeSemantics(
          child: Transform.scale(
            scale:
                1 +
                (_pressedIndex == index
                    ? _interaction.value.clamp(0.0, 1.0) * 0.035
                    : 0),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _selectDestination(index),
                borderRadius: BorderRadius.circular(28),
                focusColor: Colors.white.withValues(alpha: 0.12),
                splashColor: AppColors.primary.withValues(alpha: 0.12),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        size: 24,
                        shadows: const [
                          Shadow(
                            color: Color.fromRGBO(0, 0, 0, 0.8),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(
                              color: Color.fromRGBO(0, 0, 0, 0.8),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
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
}

class _LiquidNavClipper extends CustomClipper<Path> {
  const _LiquidNavClipper({
    required this.pressure,
    required this.touch,
    required this.drag,
  });

  final double pressure;
  final Offset touch;
  final Offset drag;

  @override
  Path getClip(Size size) {
    // Reserve space for the whole bar to swell and the drag point to stretch.
    final base = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(6.5, 6, size.width - 6.5, size.height - 6),
          const Radius.circular(36),
        ),
      );
    if (pressure == 0) return base;
    final center = touch.dx * size.width;
    final span = size.width / 3 * 0.9;
    final metric = base.computeMetrics().first;
    final path = Path();
    for (var step = 0; step < 160; step++) {
      final tangent = metric.getTangentForOffset(metric.length * step / 160)!;
      final distance = (tangent.position.dx - center).abs() / span;
      final weight = distance < 1
          ? (1 + math.cos(math.pi * distance)) / 2
          : 0.0;
      final outwardY = -tangent.vector.dx;
      final proximity =
          0.6 +
          0.4 * (1 - (tangent.position.dy / size.height - touch.dy).abs());
      final bulge =
          (2.5 + math.max(0.0, drag.dy * outwardY) * 0.5 * weight * proximity) *
          pressure;
      final point =
          tangent.position +
          Offset(tangent.vector.dy * 6.5 * pressure, outwardY * bulge);
      if (step == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant _LiquidNavClipper oldClipper) =>
      oldClipper.pressure != pressure ||
      oldClipper.touch != touch ||
      oldClipper.drag != drag;
}

class _GlassSnapshotPainter extends CustomPainter {
  const _GlassSnapshotPainter({
    required this.shader,
    required this.image,
    required this.deformation,
  });

  final FragmentShader shader;
  final ui.Image image;
  final _LiquidNavClipper deformation;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, image.width.toDouble())
      ..setFloat(1, image.height.toDouble())
      ..setFloat(2, size.width)
      ..setFloat(3, size.height)
      ..setFloat(4, 12)
      ..setFloat(5, 0)
      ..setFloat(6, deformation.touch.dx)
      ..setFloat(7, deformation.pressure)
      ..setFloat(8, deformation.drag.dy)
      ..setFloat(9, deformation.touch.dy)
      ..setImageSampler(0, image);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _GlassSnapshotPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.shader != shader ||
      deformation.shouldReclip(oldDelegate.deformation);
}

class _LiquidTabCapsule extends StatelessWidget {
  const _LiquidTabCapsule();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(29),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.14),
          blurRadius: 7,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.12),
          blurRadius: 2,
          offset: const Offset(0, -1),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(29),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.035),
                  AppColors.primary.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.035),
                ],
                stops: const [0, 0.25, 0.7, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromRGBO(255, 255, 255, 0.06),
                  Colors.transparent,
                  Color.fromRGBO(0, 0, 0, 0.1),
                ],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: const _LiquidGlassRimPainter(radius: 29),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LiquidGlassRimPainter extends CustomPainter {
  const _LiquidGlassRimPainter({required this.radius, this.deformation});

  final double radius;
  final _LiquidNavClipper? deformation;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rim = RRect.fromRectAndRadius(
      rect.deflate(0.7),
      Radius.circular(radius),
    );
    final outline = deformation?.getClip(size) ?? (Path()..addRRect(rim));
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          colors: [
            Colors.white.withValues(alpha: 0.45),
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.45),
          ],
          stops: const [0, 0.2, 0.5, 0.8, 1],
        ).createShader(rect),
    );

    canvas.drawPath(
      deformation == null ? (Path()..addRRect(rim.deflate(1.2))) : outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5)
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(255, 255, 255, 0.2),
            Colors.transparent,
            Color.fromRGBO(0, 0, 0, 0.18),
          ],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassRimPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      (deformation == null
          ? oldDelegate.deformation != null
          : oldDelegate.deformation == null ||
                deformation!.shouldReclip(oldDelegate.deformation!));
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
