import 'package:cinema_fe/core/utils/trailer_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Preview uses direct video files and rejects YouTube pages', () {
    expect(
      directPreviewUrl(Uri.parse('https://cdn.example.com/clip.mp4')),
      isNotNull,
    );
    expect(
      directPreviewUrl(
        Uri.parse('https://cdn.example.com/clip.webm?token=abc'),
      ),
      isNotNull,
    );
    expect(directPreviewUrl(Uri.parse('https://youtu.be/YoHD9XEInc0')), isNull);
    expect(directPreviewUrl(Uri.parse('file:///clip.mp4')), isNull);
  });
  test('Preview is muted, inline and limited to ten seconds', () {
    final url = Uri.parse('https://youtu.be/YoHD9XEInc0');
    final preview = youtubeEmbedUrl(url, preview: true)!;
    expect(preview.queryParameters['mute'], '1');
    expect(preview.queryParameters['end'], '10');
    expect(preview.queryParameters['playsinline'], '1');
    expect(youtubeEmbedUrl(url)!.queryParameters.containsKey('end'), isFalse);
  });
  test('Only valid YouTube video links become embedded players', () {
    for (final url in [
      'https://www.youtube.com/watch?v=YoHD9XEInc0',
      'https://youtu.be/YoHD9XEInc0?t=30',
      'https://www.youtube.com/embed/YoHD9XEInc0',
      'https://youtube.com/shorts/YoHD9XEInc0',
    ]) {
      expect(youtubeEmbedUrl(Uri.parse(url))?.path, '/embed/YoHD9XEInc0');
    }
    for (final url in [
      'https://youtube.com.evil.test/watch?v=YoHD9XEInc0',
      'https://www.youtube.com/watch?v=invalid',
      'javascript:alert(1)',
    ]) {
      expect(youtubeEmbedUrl(Uri.parse(url)), isNull);
    }
  });
}
