import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

// Only public movie, showtime and snack routes become actions. A preview card
// for each movie or snack follows the run of lines that link to it, so several
// showtimes of one movie are listed first with one card below them.
class ChatAnswer extends StatelessWidget {
  const ChatAnswer({
    required this.text,
    this.onOpenLink,
    this.recommendation,
    super.key,
  });

  final String text;
  final ValueChanged<String>? onOpenLink;
  final Widget Function(String route)? recommendation;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final spans = <InlineSpan>[];
    final blocks = <Widget>[];
    final style = AppTextStyles.bodySmall.copyWith(
      fontSize: 16,
      color: colors.textPrimary,
      height: 1.6,
    );
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    var hasLinks = false;
    final emphasis = RegExp(
      r'(?:\*\*)?\[([^\[\]\n]+)\]\((/(?:movies/[1-9][0-9]{0,15}(?:/showtimes/[1-9][0-9]{0,15})?|snacks/[1-9][0-9]{0,15}))\)(?:\*\*)?|'
      r'\*\*([^*\n]+)\*\*|\b\d+(?:[.,]\d+)*[ \t]?(?:đ|₫|VND)(?![A-Za-z0-9])',
    );
    final parsed =
        <({List<InlineSpan> children, bool heading, Set<String> cards})>[];
    for (var index = 0; index < lines.length; index++) {
      var line = lines[index];
      final heading = RegExp(r'^#{1,3}\s+').firstMatch(line);
      final bullet = RegExp(r'^\s*[-*•]\s+').firstMatch(line);
      if (heading != null) {
        line = line.substring(heading.end);
      } else if (bullet != null) {
        line = '•  ${line.substring(bullet.end)}';
        // Old saved replies have long prose bullets without Markdown; change presentation only.
        if (line.length > 120 && !line.contains('**') && !line.contains('](')) {
          final label = RegExp(r'^•  ([^:\n]{1,70}:)\s').firstMatch(line);
          if (label != null) {
            line = '**${label.group(1)}**\n${line.substring(label.end)}';
          }
          line = line.replaceAllMapped(
            RegExp(r'([.;]) +(?=\S)'),
            (match) => '${match.group(1)}\n',
          );
        }
      }
      final children = <InlineSpan>[];
      final cards = <String>{};
      var offset = 0;
      for (final match in emphasis.allMatches(line)) {
        children.add(TextSpan(text: line.substring(offset, match.start)));
        offset = match.end;
        final route = match.group(2);
        final label = match.group(1)?.replaceAll('**', '').trim();
        final open = onOpenLink;
        if (route != null &&
            label != null &&
            label.isNotEmpty &&
            open != null) {
          hasLinks = true;
          // A showtime previews its movie: /movies/1/showtimes/42 -> /movies/1
          if (recommendation != null) {
            cards.add(route.split('/').take(3).join('/'));
          }
          children.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: TextButton(
                onPressed: () => open(route),
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  minimumSize: const Size(0, 44),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
                child: Text(label),
              ),
            ),
          );
        } else {
          children.add(
            TextSpan(
              text: match.group(3) ?? match.group(0),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        }
      }
      children.add(TextSpan(text: line.substring(offset)));
      parsed.add((children: children, heading: heading != null, cards: cards));
    }
    // Cards go after the last line of each run of lines about the same items.
    final cardsAfter = <int, List<String>>{};
    var run = <String>{};
    var runEnd = -1;
    for (var index = 0; index < parsed.length; index++) {
      final cards = parsed[index].cards;
      if (cards.isEmpty) continue;
      if (run.isNotEmpty && !cards.any(run.contains)) {
        cardsAfter[runEnd] = run.toList();
        run = <String>{};
      }
      run.addAll(cards);
      runEnd = index;
    }
    if (run.isNotEmpty) cardsAfter[runEnd] = run.toList();
    for (var index = 0; index < parsed.length; index++) {
      final line = parsed[index];
      spans.add(
        TextSpan(
          style: !line.heading
              ? null
              : TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.7,
                ),
          children: line.children,
        ),
      );
      final cards = cardsAfter[index];
      if (cards != null) {
        blocks.add(Text.rich(TextSpan(children: List.of(spans)), style: style));
        spans.clear();
        for (final route in cards) {
          blocks.add(recommendation!(route));
        }
        if (index + 1 < lines.length && lines[index + 1].isEmpty) index++;
      } else if (index < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    final answer = TextSpan(children: spans);
    if (blocks.isNotEmpty) {
      return SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...blocks,
            if (spans.isNotEmpty) Text.rich(answer, style: style),
          ],
        ),
      );
    }
    if (hasLinks) return SelectionArea(child: Text.rich(answer, style: style));
    return SelectableText.rich(
      answer,
      semanticsLabel: text.replaceAll(
        RegExp(r'\*\*|^#{1,3}\s+', multiLine: true),
        '',
      ),
      style: style,
    );
  }
}
