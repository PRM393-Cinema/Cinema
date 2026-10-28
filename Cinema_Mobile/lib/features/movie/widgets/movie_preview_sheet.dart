import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/trailer_url.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/trailer_preview.dart';
import '../../../data/models/movie.dart';

Future<void> showMoviePreview(
  BuildContext context,
  Movie movie,
  VoidCallback onOpen,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: AppColors.surface,
  constraints: const BoxConstraints(maxWidth: 640),
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  builder: (_) => _MoviePreviewSheet(movie: movie, onOpen: onOpen),
);

class _MoviePreviewSheet extends StatefulWidget {
  const _MoviePreviewSheet({required this.movie, required this.onOpen});

  final Movie movie;
  final VoidCallback onOpen;

  @override
  State<_MoviePreviewSheet> createState() => _MoviePreviewSheetState();
}

class _MoviePreviewSheetState extends State<_MoviePreviewSheet>
    with WidgetsBindingObserver {
  late final Timer _deadline;
  bool _playing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deadline = Timer(const Duration(seconds: 12), _fail);
  }

  void _fail() {
    _deadline.cancel();
    if (mounted) setState(() => _failed = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached) &&
        ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deadline.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = directPreviewUrl(
      Uri.tryParse(widget.movie.previewUrl) ?? Uri(),
    );
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, right: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.movie.title,
                      style: AppTextStyles.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close preview',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: AppColors.background,
                child: _failed || url == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            'Preview unavailable. You can still view movie details.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          TrailerPreview(
                            url: url,
                            crop: false,
                            onPlaying: () {
                              _deadline.cancel();
                              if (mounted) setState(() => _playing = true);
                            },
                            onDone: _fail,
                          ),
                          if (!_playing)
                            const Center(child: CircularProgressIndicator()),
                        ],
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_failed && url != null) ...[
                    const Text(
                      '10s loop · Muted',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppButton(
                    label: 'View details',
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onOpen();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
