import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

const supportsTrailerPreview = true;

class TrailerPreview extends StatefulWidget {
  const TrailerPreview({
    required this.url,
    required this.onPlaying,
    required this.onDone,
    super.key,
  });
  final Uri url;
  final VoidCallback onPlaying;
  final VoidCallback onDone;
  @override
  State<TrailerPreview> createState() => _TrailerPreviewState();
}

class _TrailerPreviewState extends State<TrailerPreview> {
  web.HTMLVideoElement? _video;
  final _events = <StreamSubscription<web.Event>>[];
  bool _started = false;
  bool _done = false;

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    _video?.pause();
    widget.onDone();
  }

  @override
  void dispose() {
    for (final event in _events) {
      event.cancel();
    }
    _video?.pause();
    _video?.removeAttribute('src');
    _video?.load();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'video',
    onElementCreated: (element) {
      final video = element as web.HTMLVideoElement;
      _video = video;
      video
        ..muted = true
        ..defaultMuted = true
        ..autoplay = true
        ..controls = false
        ..loop = false
        ..preload = 'auto'
        ..setAttribute('playsinline', '')
        ..setAttribute('aria-label', '10 second muted movie preview');
      video.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'cover'
        ..pointerEvents = 'none';
      _events.add(
        video.onPlaying.listen((_) {
          if (!_started && mounted) {
            _started = true;
            widget.onPlaying();
          }
        }),
      );
      _events.add(
        video.onTimeUpdate.listen((_) {
          if (video.currentTime >= 10) _finish();
        }),
      );
      _events.add(video.onEnded.listen((_) => _finish()));
      _events.add(video.onError.listen((_) => _finish()));
      video.src = widget.url.toString();
      video.play().toDart.catchError((Object _) {
        _finish();
        return null;
      });
    },
  );
}
