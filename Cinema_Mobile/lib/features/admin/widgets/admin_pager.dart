import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import 'admin_catalog_layout.dart';

// Previous / Next under a paged list; a null onOpen disables both while the
// page is busy.
class AdminPager extends StatelessWidget {
  const AdminPager({
    required this.page,
    required this.totalPages,
    required this.onOpen,
    super.key,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int>? onOpen;

  @override
  Widget build(BuildContext context) {
    if (isCatalogDesktop(context)) {
      return Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        children: [
          TextButton(
            onPressed: page > 1 && onOpen != null
                ? () => onOpen!(page - 1)
                : null,
            child: const Text('Previous'),
          ),
          Text('Page $page of $totalPages', style: AppTextStyles.caption),
          TextButton(
            onPressed: page < totalPages && onOpen != null
                ? () => onOpen!(page + 1)
                : null,
            child: const Text('Next'),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: AppButton.secondary(
            label: 'Previous',
            onPressed: page > 1 && onOpen != null
                ? () => onOpen!(page - 1)
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('$page/$totalPages', style: AppTextStyles.caption),
        ),
        Expanded(
          child: AppButton.secondary(
            label: 'Next',
            onPressed: page < totalPages && onOpen != null
                ? () => onOpen!(page + 1)
                : null,
          ),
        ),
      ],
    );
  }
}
