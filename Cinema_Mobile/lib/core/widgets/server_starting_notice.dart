import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../network/server_wake_up.dart';

// While requests wait for sleeping services to start, says so at the top of
// every page, so a slow first load does not look broken. Sits above the
// navigator (MaterialApp.builder), so it uses no tooltips or dialogs.
class ServerStartingNotice extends StatelessWidget {
  const ServerStartingNotice({required this.child, this.wakeUp, super.key});

  final Widget child;

  // Defaults to the configured wake-up; nothing is shown without one.
  final ServerWakeUp? wakeUp;

  @override
  Widget build(BuildContext context) {
    final wake = wakeUp ?? ServerWakeUp.configured;
    if (wake == null) return child;

    return Stack(
      children: [
        child,
        ValueListenableBuilder<int>(
          valueListenable: wake.waiting,
          builder: (context, waiting, _) {
            if (waiting == 0) return const SizedBox.shrink();
            final palette = AppPalette.of(context);
            return Positioned(
              top: MediaQuery.paddingOf(context).top + AppSpacing.md,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: Center(
                child: Material(
                  key: const Key('serverStartingNotice'),
                  color: palette.surfaceSoft,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: palette.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            'Starting the server, this can take up to a '
                            'minute…',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
