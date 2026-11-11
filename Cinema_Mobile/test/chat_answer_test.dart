import 'package:cinema_fe/features/chat/widgets/chat_answer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Movie and snack links appear in order inside the answer', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAnswer(
            text:
                '- [**Inception**](/movies/1) — Sci-fi\n'
                '- **[Combo Couple](/snacks/2)** — 57.000đ',
            onOpenLink: opened.add,
          ),
        ),
      ),
    );
    expect(find.byType(TextButton), findsNWidgets(2));
    final answer = tester.widget<Text>(
      find
          .descendant(
            of: find.byType(ChatAnswer),
            matching: find.byWidgetPredicate(
              (widget) => widget is Text && widget.textSpan != null,
            ),
          )
          .first,
    );
    expect(
      answer.textSpan!.toPlainText(),
      '•  \uFFFC — Sci-fi\n•  \uFFFC — 57.000đ',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Inception'));
    await tester.tap(find.widgetWithText(TextButton, 'Combo Couple'));
    expect(opened, ['/movies/1', '/snacks/2']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Showtimes of one movie link to their seat maps, then one card', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAnswer(
            text:
                '### [Chuyến Tàu Sinh Tử](/movies/1)\n'
                '- [08:00](/movies/1/showtimes/42) — 2D, 85.000đ\n'
                '- [08:15](/movies/1/showtimes/43) — 2D, 85.000đ\n'
                '\n'
                'Bạn muốn đặt suất nào?',
            onOpenLink: opened.add,
            recommendation: (route) => Text('Card $route'),
          ),
        ),
      ),
    );

    expect(find.text('Card /movies/1'), findsOneWidget);
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final card = top(find.text('Card /movies/1'));
    expect(card, greaterThan(top(find.widgetWithText(TextButton, '08:15'))));
    expect(
      card,
      lessThan(top(find.textContaining('Bạn muốn', findRichText: true))),
    );

    await tester.tap(find.widgetWithText(TextButton, '08:15'));
    await tester.tap(find.widgetWithText(TextButton, 'Chuyến Tàu Sinh Tử'));
    expect(opened, ['/movies/1/showtimes/43', '/movies/1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Every movie and snack gets a card after its own lines', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChatAnswer(
              text:
                  '- [Inception](/movies/1) — [19:00](/movies/1/showtimes/42)\n'
                  '- [Dune](/movies/2) — [20:00](/movies/2/showtimes/50)\n'
                  '- [Combo](/snacks/3) — 57.000đ',
              onOpenLink: (_) {},
              recommendation: (route) => Text('Card $route'),
            ),
          ),
        ),
      ),
    );

    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final cards = [
      for (final route in ['/movies/1', '/movies/2', '/snacks/3'])
        top(find.text('Card $route')),
    ];
    expect(cards, orderedEquals([...cards]..sort()));
    expect(cards[0], lessThan(top(find.widgetWithText(TextButton, 'Dune'))));
    expect(cards[1], lessThan(top(find.widgetWithText(TextButton, 'Combo'))));
    expect(tester.takeException(), isNull);
  });

  testWidgets('External and malformed links never become navigation actions', (
    tester,
  ) async {
    const text =
        '[External](https://example.com/movies/1)\n'
        '[Script](javascript:alert)\n[Account](/profile)\n'
        '[Zero](/movies/0)\n[Negative](/movies/-1)\n'
        '[Query](/movies/1?redirect=elsewhere)\n'
        '[No showtime](/movies/1/showtimes/0)\n'
        '[Deeper](/movies/1/showtimes/2/seats)\n'
        '[Overflow](/movies/99999999999999999999999999)';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAnswer(
            text: text,
            onOpenLink: (_) => fail('Invalid link opened'),
          ),
        ),
      ),
    );
    expect(find.byType(TextButton), findsNothing);
    expect(
      tester
          .widget<SelectableText>(find.byType(SelectableText))
          .textSpan!
          .toPlainText(),
      text,
    );
  });

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
