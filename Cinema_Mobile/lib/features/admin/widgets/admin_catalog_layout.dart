import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/cinema_account_widgets.dart';

// Admin routes subtract the sidebar from MediaQuery; use the window breakpoint.
bool isCatalogDesktop(BuildContext context) =>
    View.of(context).physicalSize.width /
        MediaQuery.devicePixelRatioOf(context) >=
    desktopBreakpoint;

class AdminCatalogToolbar extends StatelessWidget {
  const AdminCatalogToolbar({
    required this.search,
    required this.action,
    this.filter,
    this.filterWidth = 200,
    super.key,
  });
  final Widget search;
  final Widget action;
  final Widget? filter;
  final double filterWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < filterWidth + 400) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: AppSpacing.md),
            if (filter != null) ...[
              filter!,
              const SizedBox(height: AppSpacing.md),
            ],
            Align(alignment: Alignment.centerLeft, child: action),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: search),
          if (filter != null) ...[
            const SizedBox(width: AppSpacing.md),
            SizedBox(width: filterWidth, child: filter),
          ],
          const SizedBox(width: AppSpacing.lg),
          action,
        ],
      );
    },
  );
}

class AdminCatalogTable extends StatelessWidget {
  const AdminCatalogTable({
    required this.columns,
    required this.rows,
    super.key,
  });
  final List<DataColumn> columns;
  final List<DataRow> rows;

  @override
  Widget build(BuildContext context) => CinemaPanel(
    padding: EdgeInsets.zero,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 72,
            dataRowMaxHeight: double.infinity,
            horizontalMargin: AppSpacing.lg,
            columnSpacing: AppSpacing.lg,
            columns: columns,
            rows: rows,
          ),
        ),
      ),
    ),
  );
}
