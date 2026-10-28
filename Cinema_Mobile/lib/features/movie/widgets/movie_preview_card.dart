import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/trailer_url.dart';
import '../../../core/widgets/trailer_preview.dart';
import '../../../data/models/movie.dart';
import 'movie_card.dart';

class MoviePreviewCard extends StatefulWidget {
  const MoviePreviewCard({
    required this.movie,
    required this.active,
    required this.onOpen,
    super.key,
  });
  final Movie movie;
  final ValueNotifier<int?> active;
  final VoidCallback onOpen;
  @override
  State<MoviePreviewCard> createState() => _MoviePreviewCardState();
}

class _MoviePreviewCardState extends State<MoviePreviewCard> {
  Timer? _hover;
  Timer? _deadline;
  bool get _active => widget.active.value == widget.movie.id;
  bool get _available =>
      supportsTrailerPreview &&
      directPreviewUrl(Uri.tryParse(widget.movie.previewUrl) ?? Uri()) != null;

  @override
  void initState() {
    super.initState();
    widget.active.addListener(_changed);
  }

  void _changed() {
    _deadline?.cancel();
    if (_active) {
      // Return to the poster if embedding or autoplay is blocked.
      _deadline = Timer(const Duration(seconds: 12), _stop);
    }
    if (mounted) setState(() {});
  }

  void _stop() {
    _hover?.cancel();
    if (_active) widget.active.value = null;
  }

  void _start() {
    if (_available && !_active) widget.active.value = widget.movie.id;
  }

  void _open() {
    _stop();
    widget.onOpen();
  }

  @override
  void dispose() {
    _hover?.cancel();
    _deadline?.cancel();
    widget.active.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (_) {
        if (!reduceMotion) {
          _hover = Timer(const Duration(milliseconds: 450), _start);
        }
      },
      onExit: (_) => _stop(),
      child: AnimatedScale(
        scale: _active && !reduceMotion ? 1.04 : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MovieCard(
              title: widget.movie.title,
              posterUrl: widget.movie.posterUrl,
              genre: widget.movie.genre,
              duration: widget.movie.durationText,
              ageRating: widget.movie.ageRating,
              badge: widget.movie.isComingSoon()
                  ? formatShortDate(widget.movie.releaseDate!)
                  : null,
              onTap: () {
                if (_available && MediaQuery.sizeOf(context).width < 600) {
                  _start();
                } else {
                  _open();
                }
              },
            ),
            if (_active)
              Material(
                color: AppColors.surface,
                borderRadius: AppRadius.borderRadiusMd,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Expanded(
                      child: TrailerPreview(
                        key: ValueKey(widget.movie.id),
                        url: directPreviewUrl(Uri.parse(widget.movie.previewUrl))!,
                        onPlaying: () {
                          _deadline?.cancel();
                          _deadline = Timer(const Duration(seconds: 10), _stop);
                        },
                        onDone: _stop,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _open,
                            child: const Text('View details'),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Stop preview',
                          onPressed: _stop,
                          icon: const Icon(Icons.stop_circle_outlined),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '10s preview · Muted',
                        style: TextStyle(fontSize: 12),
                      ),
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
