import 'package:flutter/widgets.dart';

const supportsTrailerPreview = false;

class TrailerPreview extends StatelessWidget {
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}
