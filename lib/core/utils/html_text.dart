// Turns the HTML emails stored by the notification service into plain text.
String htmlToPlainText(String html) {
  var text = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</(p|div|h[1-6]|li|tr|table)>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '');

  text = text
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);'),
        (match) => String.fromCharCode(int.parse(match[1]!, radix: 16)),
      )
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (match) => String.fromCharCode(int.parse(match[1]!)),
      )
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');

  return text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}
