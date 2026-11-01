import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// Reveal each section once as it enters the page's scrolling viewport.
class ScrollReveal extends StatefulWidget {
  const ScrollReveal({required this.child, super.key});
  final Widget child;

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal> {
  ScrollPosition? _position;
  bool _revealed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (_position != position) {
      _position?.removeListener(_checkVisibility);
      _position = position;
      _position?.addListener(_checkVisibility);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  void _checkVisibility() {
    if (!mounted || _revealed) return;
    final position = _position;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    final top = viewport?.getOffsetToReveal(box, 0).offset ?? 0;
    final visible = position == null
        ? box.size.height
        : math.min(
                top + box.size.height,
                position.pixels + position.viewportDimension,
              ) -
              math.max(top, position.pixels);
    if (position == null ||
        viewport == null ||
        visible >= math.min(80, box.size.height * 0.2)) {
      setState(() => _revealed = true);
      _position?.removeListener(_checkVisibility);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_checkVisibility);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: reducedMotion || _revealed ? 1 : 0),
      duration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 750),
      curve: Curves.easeOut,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
