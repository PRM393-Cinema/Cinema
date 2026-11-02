import 'package:http/http.dart' as http;

// Phones and desktop: a plain GET; the answer does not matter.
Future<void> wakePing(Uri url) async {
  final client = http.Client();
  try {
    await client.get(url).timeout(const Duration(seconds: 90));
  } on Object {
    // Still starting or unreachable: the next ping or retry takes over.
  } finally {
    client.close();
  }
}
