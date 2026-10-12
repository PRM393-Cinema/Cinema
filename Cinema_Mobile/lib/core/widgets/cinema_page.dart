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
    this.width = PageWidth.form,
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  // How wide the page is on the website; the title lines up with it.
  final PageWidth width;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CinemaBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: widthPadding(context, AppSpacing.lg, width),
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
