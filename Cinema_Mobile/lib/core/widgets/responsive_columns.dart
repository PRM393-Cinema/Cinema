import 'package:flutter/widgets.dart';

import '../../app/theme/app_spacing.dart';

// Website layout of a page: the main content with a side column next to it
// (summary, totals, actions). In the app layout, or when there is not enough
// room, the side column goes under the main content.
class ResponsiveColumns extends StatelessWidget {
  const ResponsiveColumns({
    required this.main,
    required this.side,
    this.sideWidth = 380,
    this.sideBySideFrom = 820,
    this.sideOnLeft = false,
    super.key,
  });

  final List<Widget> main;
  final List<Widget> side;
  final double sideWidth;
  final double sideBySideFrom;

  // A side column on the left, like an account menu.
  final bool sideOnLeft;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < sideBySideFrom) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [...main, ...side],
        );
      }
      final mainColumn = Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: main,
        ),
      );
      final sideColumn = SizedBox(
        width: sideWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: side,
        ),
      );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sideOnLeft
            ? [sideColumn, const SizedBox(width: AppSpacing.xl), mainColumn]
            : [mainColumn, const SizedBox(width: AppSpacing.xl), sideColumn],
      );
    },
  );
}

// Cards in as many columns as fit, each at least [minCardWidth] wide (one
// column on a phone). Cards keep their own height, filling the columns from
// left to right.
class CardColumns extends StatelessWidget {
  const CardColumns({
    required this.children,
    this.minCardWidth = 420,
    this.maxColumns = 3,
    this.spacing = AppSpacing.md,
    this.runSpacing,
    super.key,
  });

  final List<Widget> children;
  final double minCardWidth;
  final int maxColumns;

  // Space between columns, and between cards unless [runSpacing] is given
  // (0 for cards that bring their own bottom padding).
  final double spacing;
  final double? runSpacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fit = ((constraints.maxWidth + spacing) / (minCardWidth + spacing))
          .floor();
      final columns = fit.clamp(1, maxColumns);

      Widget column(List<Widget> cards) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, card) in cards.indexed) ...[
            if (index > 0) SizedBox(height: runSpacing ?? spacing),
            card,
          ],
        ],
      );

      if (columns == 1) return column(children);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columns; c++) ...[
            if (c > 0) SizedBox(width: spacing),
            Expanded(
              child: column([
                for (var i = c; i < children.length; i += columns) children[i],
              ]),
            ),
          ],
        ],
      );
    },
  );
}
