import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../utils/layout.dart';

// shortcut: paginate loaded records; use server paging for large histories.
class PaginatedCards extends StatefulWidget {
  const PaginatedCards({
    required this.itemCount,
    required this.itemBuilder,
    this.resetKey,
    this.mobileColumns = 1,
    this.equalHeights = false,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Object? resetKey;
  final int mobileColumns;
  final bool equalHeights;
  static const pageSize = 10;

  @override
  State<PaginatedCards> createState() => _PaginatedCardsState();
}

class _PaginatedCardsState extends State<PaginatedCards> {
  int _page = 1;

  @override
  void didUpdateWidget(covariant PaginatedCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetKey != oldWidget.resetKey) _page = 1;
    _page = _page.clamp(1, math.max(1, (widget.itemCount + 9) ~/ 10));
  }

  void _open(int page) {
    setState(() => _page = page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    final columns = desktop
        ? (MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 2 : 4)
        : widget.mobileColumns;
    final pages = math.max(1, (widget.itemCount + 9) ~/ 10);
    final start = (_page - 1) * PaginatedCards.pageSize;
    final end = math.min(start + PaginatedCards.pageSize, widget.itemCount);
    final radius = desktop ? 2 : 1;
    final firstPage = math.max(1, math.min(_page - radius, pages - radius * 2));
    final lastPage = math.min(pages, firstPage + radius * 2);
    Widget cardRow(int row) => Row(
      crossAxisAlignment: widget.equalHeights
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        for (var column = 0; column < columns; column++) ...[
          if (column > 0) const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: row + column < end
                ? widget.itemBuilder(context, row + column)
                : const SizedBox(),
          ),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var row = start; row < end; row += columns) ...[
          if (row > start) const SizedBox(height: AppSpacing.xl),
          KeyedSubtree(
            key: ValueKey((widget.resetKey, _page, row)),
            child: widget.equalHeights
                ? IntrinsicHeight(child: cardRow(row))
                : cardRow(row),
          ),
        ],
        if (pages > 1) ...[
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Semantics(
              liveRegion: true,
              child: Text(
                'Page $_page of $pages',
                style: AppTextStyles.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              IconButton(
                key: const Key('previousPage'),
                tooltip: 'Previous page',
                onPressed: _page > 1 ? () => _open(_page - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              for (var number = firstPage; number <= lastPage; number++)
                Semantics(
                  selected: number == _page,
                  child: TextButton(
                    key: ValueKey('page-$number'),
                    onPressed: () => _open(number),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.square(44),
                      foregroundColor: number == _page
                          ? AppPalette.of(context).primary
                          : AppPalette.of(context).textSecondary,
                      side: BorderSide(
                        color: number == _page
                            ? AppPalette.of(context).primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Text('$number', semanticsLabel: 'Page $number'),
                  ),
                ),
              IconButton(
                key: const Key('nextPage'),
                tooltip: 'Next page',
                onPressed: _page < pages ? () => _open(_page + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
