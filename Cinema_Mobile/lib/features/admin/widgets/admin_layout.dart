import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/cinema_account_widgets.dart';

// The search boxes, filters and main button of a list page: full width in the
// app layout, a form-wide block on the left of a website page (the results
// below use the whole width).
class AdminControls extends StatelessWidget {
  const AdminControls({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: contentMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

// Dashboard numbers: two per row in the app layout, one row on the website.
class StatTiles extends StatelessWidget {
  const StatTiles({required this.tiles, super.key});

  final List<(String, int, IconData)> tiles;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final perRow = isDesktopLayout(context) ? tiles.length.clamp(1, 4) : 2;
      final width =
          (constraints.maxWidth - (perRow - 1) * AppSpacing.md) / perRow;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final (label, count, icon) in tiles)
            SizedBox(
              width: width,
              child: CinemaPanel(
                surfaceOpacity: 0.8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: AppColors.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text('$count', style: AppTextStyles.display),
                    const SizedBox(height: AppSpacing.xs),
                    Text(label, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
