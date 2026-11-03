import 'package:cinema_fe/features/chat/widgets/chat_answer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Legacy recommendation splits facts and emphasizes prices without rewriting history',
    (tester) async {
      const text =
          'Mình hiểu budget của hai bạn là 300.000đ nhé!\n\n• Nhẹ nhàng, tình cảm: Bố Già — 09:15 ngày 06/11/2026, 2D. Ghế NORMAL 85.000đ/vé, hai vé 170.000đ; còn 130.000đ trong ngân sách cho bắp nước.';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ChatAnswer(text: text)),
        ),
      );
      final widget = tester.widget<SelectableText>(find.byType(SelectableText));
      final rendered = widget.textSpan!.toPlainText();
      expect(rendered, contains('Nhẹ nhàng, tình cảm:\nBố Già'));
      expect(rendered, contains('2D.\nGhế NORMAL'));
      expect(rendered, contains('170.000đ;\ncòn 130.000đ'));
      expect(widget.semanticsLabel, text);
      final boldText = <String>[];
      void collect(TextSpan span) {
        if (span.style?.fontWeight == FontWeight.w700) {
          boldText.add(span.toPlainText());
        }
        for (final child in span.children ?? <InlineSpan>[]) {
          if (child is TextSpan) collect(child);
        }
      }

      collect(widget.textSpan!);
      expect(
        boldText,
        containsAll([
          'Nhẹ nhàng, tình cảm:',
          '300.000đ',
          '170.000đ',
          '130.000đ',
        ]),
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final mode in ThemeMode.values) {
    testWidgets('Chat answer headings, lists and bold wrap in $mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const answer =
          '### Gợi ý cho hai người\n\n**Bố Già**\n- Suất chiếu: 09:15 · 2D\n- Hai vé: **170.000đ**\n- Còn lại: **130.000đ**\n\nBạn muốn chọn suất nào?';
      await tester.pumpWidget(
        MaterialApp(
          themeMode: mode,
          darkTheme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(width: 320, child: ChatAnswer(text: answer)),
          ),
        ),
      );
      final selectable = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      final rendered = selectable.textSpan!.toPlainText();
      expect(rendered, contains('•  Hai vé: 170.000đ'));
      expect(rendered, isNot(contains('**')));
      expect(rendered, isNot(contains('###')));
      final heading = selectable.textSpan!.children!.first as TextSpan;
      expect(heading.style!.fontWeight, FontWeight.w700);
      expect(selectable.semanticsLabel, contains('170.000đ'));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Plain text and untrusted HTML remain literal selectable text', (
    tester,
  ) async {
    const text =
        'Old reply\n• 85.000đ/vé\n<script>alert(1)</script>\n**unfinished';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatAnswer(text: text)),
      ),
    );
    expect(
      tester
          .widget<SelectableText>(find.byType(SelectableText))
          .textSpan!
          .toPlainText(),
      text.replaceFirst('• ', '•  '),
    );
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
