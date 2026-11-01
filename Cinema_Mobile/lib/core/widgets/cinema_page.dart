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
    this.subtitle,
    this.showHeader = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool showHeader;
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
            if (showHeader)
              Padding(
                padding: widthPadding(context, AppSpacing.lg, width),
                child: CinemaPageHeader(
                  title: title,
                  subtitle: subtitle,
                  actions: actions,
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

class CinemaPageHeader extends StatelessWidget {
  const CinemaPageHeader({
    required this.title,
    this.actions = const [],
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (Navigator.canPop(context)) ...[
        const BackButton(),
        const SizedBox(width: AppSpacing.sm),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: subtitle != null && isDesktopLayout(context)
                  ? AppTextStyles.heading1
                  : AppTextStyles.heading2,
            ),
            if (subtitle != null && isDesktopLayout(context)) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle!, style: AppTextStyles.bodySmall),
            ],
          ],
        ),
      ),
      ...actions,
    ],
  );
}
