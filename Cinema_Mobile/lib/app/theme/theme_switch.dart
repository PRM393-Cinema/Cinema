import 'package:flutter/material.dart';

class ThemeSwitch extends StatelessWidget {
  const ThemeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = ThemeSettings.maybeOf(context);
    if (settings == null) return const SizedBox.shrink();
    final isLight = Theme.of(context).brightness == Brightness.light;
    return IconButton(
      key: const Key('themeSwitch'),
      tooltip: isLight ? 'Switch to dark mode' : 'Switch to light mode',
      isSelected: isLight,
      onPressed: settings.toggle,
      icon: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: RotationTransition(
            turns: Tween<double>(begin: -0.125, end: 0).animate(animation),
            child: child,
          ),
        ),
        child: Icon(
          isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          key: ValueKey(isLight),
        ),
      ),
    );
  }
}

class ThemeSettings extends InheritedWidget {
  const ThemeSettings({required this.toggle, required super.child, super.key});

  final VoidCallback toggle;

  static ThemeSettings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeSettings>();

  @override
  bool updateShouldNotify(ThemeSettings oldWidget) =>
      toggle != oldWidget.toggle;
}
