Uri? directPreviewUrl(Uri url) {
  if (!url.hasScheme &&
      !url.hasAuthority &&
      url.path.startsWith('/previews/') &&
      !url.pathSegments.contains('..')) {
    final path = url.path.toLowerCase();
    return path.endsWith('.mp4') || path.endsWith('.webm')
        ? Uri.base.resolveUri(url)
        : null;
  }
  if ((url.scheme != 'https' && url.scheme != 'http') || url.host.isEmpty)
    return null;
  final path = url.path.toLowerCase();
  return path.endsWith('.mp4') || path.endsWith('.webm') ? url : null;
}

Uri? youtubeEmbedUrl(Uri trailer, {bool preview = false}) {
  if (trailer.scheme != 'https' && trailer.scheme != 'http') return null;
  final host = trailer.host.toLowerCase();
  String? id;
  if (host == 'youtu.be') {
    id = trailer.pathSegments.firstOrNull;
  } else if (const [
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com',
  ].contains(host)) {
    if (trailer.path == '/watch') {
      id = trailer.queryParameters['v'];
    } else if (trailer.pathSegments.length == 2 &&
        const [
          'embed',
          'shorts',
          'live',
        ].contains(trailer.pathSegments.first)) {
      id = trailer.pathSegments[1];
    }
  }
  if (id == null || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) return null;
  return Uri.https('www.youtube-nocookie.com', '/embed/$id', {
    'autoplay': '1',
    'rel': '0',
    if (preview) ...{
      'mute': '1',
      'start': '0',
      'end': '10',
      'playsinline': '1',
      'enablejsapi': '1',
      'controls': '0',
      'disablekb': '1',
      'fs': '0',
    },
  });
}
