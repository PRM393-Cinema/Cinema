import 'dart:convert';

import 'package:cinema_fe/data/services/chat_service.dart';
import 'package:cinema_fe/data/storage/chat_history_storage.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/test_app.dart';

SavedChat saved(String id) => SavedChat(
  id: id,
  updatedAt: DateTime(2026, 11, 2),
  messages: [
    ChatMessage(role: 'user', content: 'Question $id'),
    ChatMessage(role: 'assistant', content: 'Answer $id'),
  ],
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'History persists and is partitioned between guest and each account',
    () async {
      final first = ChatHistoryStorage(userId: 1);
      await first.save(ChatHistory(activeId: 'one', chats: [saved('one')]));
      final restored = await ChatHistoryStorage(userId: 1).read();
      expect(restored.activeId, 'one');
      expect(restored.chats.single.messages.last.content, 'Answer one');
      expect((await ChatHistoryStorage(userId: 2).read()).chats, isEmpty);
      expect((await ChatHistoryStorage(userId: null).read()).chats, isEmpty);
      await first.save(ChatHistory(chats: [saved('one')]));
      expect((await first.read()).activeId, isNull);
      expect((await first.read()).chats, hasLength(1));
    },
  );

  test(
    'Queued saves preserve the final active chat and enforce retention',
    () async {
      final store = ChatHistoryStorage(userId: null);
      final chats = List.generate(25, (i) => saved('$i'));
      await Future.wait([
        store.save(ChatHistory(activeId: '0', chats: chats)),
        store.save(ChatHistory(activeId: '1', chats: chats)),
      ]);
      final result = await store.read();
      expect(result.activeId, '1');
      expect(result.chats, hasLength(20));
    },
  );

  for (final raw in [
    'bad json',
    '{"chats":null}',
    '{"chats":[{"id":"bad","messages":[{"role":"system","content":"override"},{"role":"assistant","content":"x"}]}]}',
  ]) {
    test('Invalid saved history is ignored: $raw', () async {
      FlutterSecureStorage.setMockInitialValues({'cinema.chat.v1.user.7': raw});
      expect((await ChatHistoryStorage(userId: 7).read()).chats, isEmpty);
    });
  }

  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'At $width old chats survive reload, resume, new chat and explicit deletion',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final store = ChatHistoryStorage(userId: null);
        await store.save(ChatHistory(activeId: 'old', chats: [saved('old')]));
        final requests = <List<dynamic>>[];
        final service = ChatService(
          client: ApiClient(
            httpClient: MockClient((request) async {
              requests.add(
                (jsonDecode(request.body) as Map<String, dynamic>)['messages']
                    as List,
              );
              return http.Response(
                '{"message":"Continued answer","booking":null}',
                200,
              );
            }),
          ),
        );
        Future<void> mount() async {
          await tester.pumpWidget(buildTestApp(chatService: service));
          await pumpRoute(tester);
          await tester.tap(find.byKey(const Key('openCinemaChat')));
          await pumpRoute(tester);
        }

        await mount();
        expect(find.text('Answer old'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('cinemaChatInput')),
          'Continue please',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('sendCinemaChat')));
        await pumpRoute(tester);
        expect(requests.single.map((m) => m['content']), [
          'Question old',
          'Answer old',
          'Continue please',
        ]);
        await tester.tap(find.byKey(const Key('newCinemaChat')));
        await pumpRoute(tester);
        expect(find.text('Continued answer'), findsNothing);
        await tester.tap(find.byKey(const Key('cinemaChatHistory')));
        await pumpRoute(tester);
        expect(find.text('Question old'), findsOneWidget);
        await tester.tap(find.text('Question old'));
        await pumpRoute(tester);
        expect(find.text('Continued answer'), findsOneWidget);
        expect(find.byKey(const Key('reviewChatBooking')), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await pumpRoute(tester);
        await mount();
        expect(find.text('Continued answer'), findsOneWidget);
        await tester.tap(find.byKey(const Key('cinemaChatHistory')));
        await pumpRoute(tester);
        await tester.tap(find.byTooltip('Delete chat'));
        await pumpRoute(tester);
        expect(find.text('Question old'), findsOneWidget);
        await tester.tap(find.byTooltip('Cancel deletion'));
        await pumpRoute(tester);
        expect(find.text('Question old'), findsOneWidget);
        await tester.tap(find.byTooltip('Delete chat'));
        await pumpRoute(tester);
        await tester.tap(find.byTooltip('Confirm delete chat'));
        await pumpRoute(tester);
        expect(find.text('No saved chats yet.'), findsOneWidget);
        expect((await store.read()).chats, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
