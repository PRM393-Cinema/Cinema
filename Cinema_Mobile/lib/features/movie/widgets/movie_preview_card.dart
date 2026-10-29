import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/trailer_url.dart';
import '../../../core/widgets/app_network_image.dart';
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
  Timer? _deadline;
  bool _playing = false;
  bool _failed = false;
  bool get _active => widget.active.value == widget.movie.id;
  bool get _available =>
      supportsTrailerPreview &&
      directPreviewUrl(Uri.tryParse(widget.movie.previewUrl) ?? Uri()) != null;

  @override
  void initState() {
    super.initState();
    widget.active.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant MoviePreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      oldWidget.active.removeListener(_changed);
      widget.active.addListener(_changed);
    }
    if (oldWidget.movie.id != widget.movie.id ||
        oldWidget.movie.previewUrl != widget.movie.previewUrl ||
        oldWidget.active != widget.active) {
      _changed();
    }
  }

  void _changed() {
    _deadline?.cancel();
    if (_active && _available) {
      _deadline = Timer(const Duration(seconds: 12), _fail);
    }
    if (mounted) {
      setState(() {
        _playing = false;
        _failed = false;
      });
    }
  }

  void _stop() {
    if (_active) widget.active.value = null;
  }

  void _fail() {
    if (!mounted || !_active) return;
    _deadline?.cancel();
    setState(() {
      _failed = true;
      _playing = false;
    });
  }

  void _start() {
    if (!_active) widget.active.value = widget.movie.id;
  }

  void _open() {
    _stop();
    widget.onOpen();
  }

  void _tap() {
    if (_active) {
      _open();
    } else {
      _start();
    }
  }

  @override
  void dispose() {
    _deadline?.cancel();
    widget.active.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (event) {
        if (event.kind == PointerDeviceKind.mouse && !reduceMotion) {
          _start();
        }
      },
      onExit: (event) {
        if (event.kind == PointerDeviceKind.mouse) _stop();
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: _active && !reduceMotion ? 1.08 : 1),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          // Zoom the artwork while keeping taps inside the original grid slot.
          transformHitTests: false,
          child: child,
        ),
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
              onTap: _tap,
            ),
            if (_active)
              Material(
                color: AppColors.surface,
                borderRadius: AppRadius.borderRadiusMd,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _open,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_available && !_failed)
                              TrailerPreview(
                                key: ValueKey(widget.movie.id),
                                url: directPreviewUrl(
                                  Uri.parse(widget.movie.previewUrl),
                                )!,
                                onPlaying: () {
                                  _deadline?.cancel();
                                  if (mounted && _active) {
                                    setState(() => _playing = true);
                                  }
                                },
                                onDone: _fail,
                              ),
                            if (!_playing) ...[
                              AppNetworkImage(imageUrl: widget.movie.posterUrl),
                              if (_available && !_failed)
                                const Center(
                                  child: SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              if (!_available || _failed)
                                Center(
                                  child: Container(
                                    color: AppColors.background.withValues(
                                      alpha: 0.9,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Preview unavailable',
                                          textAlign: TextAlign.center,
                                        ),
                                        if (_available)
                                          TextButton(
                                            onPressed: _changed,
                                            child: const Text('Retry preview'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
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
                        'Tap again for details · Muted',
                        textAlign: TextAlign.center,
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
