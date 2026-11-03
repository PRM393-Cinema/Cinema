import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

// A deliberately small text format: headings, lists and bold, with no HTML or executable links.
class ChatAnswer extends StatelessWidget {
  const ChatAnswer({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final spans = <InlineSpan>[];
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final emphasis = RegExp(
      r'\*\*([^*\n]+)\*\*|\b\d+(?:[.,]\d+)*[ \t]?(?:đ|₫|VND)(?![A-Za-z0-9])',
    );
    for (var index = 0; index < lines.length; index++) {
      var line = lines[index];
      final heading = RegExp(r'^#{1,3}\s+').firstMatch(line);
      final bullet = RegExp(r'^\s*[-*•]\s+').firstMatch(line);
      if (heading != null) {
        line = line.substring(heading.end);
      } else if (bullet != null) {
        line = '•  ${line.substring(bullet.end)}';
        // Old saved replies have long prose bullets without Markdown; change presentation only.
        if (line.length > 120 && !line.contains('**')) {
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
      var offset = 0;
      for (final match in emphasis.allMatches(line)) {
        children.add(TextSpan(text: line.substring(offset, match.start)));
        children.add(
          TextSpan(
            text: match.group(1) ?? match.group(0),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
        offset = match.end;
      }
      children.add(TextSpan(text: line.substring(offset)));
      spans.add(
        TextSpan(
          style: heading == null
              ? null
              : TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.7,
                ),
          children: children,
        ),
      );
      if (index < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return SelectableText.rich(
      TextSpan(children: spans),
      semanticsLabel: text.replaceAll(
        RegExp(r'\*\*|^#{1,3}\s+', multiLine: true),
        '',
      ),
      style: AppTextStyles.bodySmall.copyWith(
        fontSize: 16,
        color: colors.textPrimary,
        height: 1.6,
      ),
    );
  }
}
