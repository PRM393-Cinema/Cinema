import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../utils/layout.dart';
import 'cinema_background.dart';

class CinemaPage extends StatelessWidget {
  const CinemaPage({
    required this.title,
    required this.child,
    this.actions = const [],
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CinemaBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: centeredPadding(context, AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: AppTextStyles.heading2)),
                  ...actions,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}
