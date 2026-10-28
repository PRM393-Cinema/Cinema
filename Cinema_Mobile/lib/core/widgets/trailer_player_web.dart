import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../utils/trailer_url.dart';

Future<void> showMovieTrailer(BuildContext context, Uri trailer, String title) {
  final embed = youtubeEmbedUrl(trailer);
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Row(
                children: [
                  Expanded(child: Text('$title · Trailer', maxLines: 2)),
                  IconButton(
                    tooltip: 'Close trailer',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: embed == null
                    ? const Center(
                        child: Text('This trailer cannot be played here.'),
                      )
                    : HtmlElementView.fromTagName(
                        tagName: 'iframe',
                        onElementCreated: (element) {
                          final frame = element as web.HTMLIFrameElement;
                          frame
                            ..src = embed.toString()
                            ..title = '$title trailer'
                            ..allow = 'autoplay; encrypted-media; fullscreen; picture-in-picture'
                            ..allowFullscreen = true
                            ..referrerPolicy =
                                'strict-origin-when-cross-origin';
                          frame.style
                            ..width = '100%'
                            ..height = '100%'
                            ..border = '0';
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
