import 'dart:async';
import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/network/server_wake_up.dart';
import 'package:cinema_fe/data/services/chat_service.dart';
import 'package:cinema_fe/features/chat/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/test_app.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'Chat never automatically repeats a billable request during server wake-up',
    () async {
      var calls = 0;
      final service = ChatService(
        client: ApiClient(
          wakeUp: ServerWakeUp(urls: const [], retryDelays: [Duration.zero]),
          httpClient: MockClient((_) async {
            calls++;
            return http.Response(
              '{"detail":"Cinema AI is not configured yet."}',
              503,
            );
          }),
        ),
      );
      await expectLater(
        service.reply([const ChatMessage(role: 'user', content: 'Hello')]),
        throwsException,
      );
      expect(calls, 1);
    },
  );

  for (final light in [false, true]) {
    for (final size in [const Size(1440, 900), const Size(375, 812)]) {
      testWidgets(
        'Chat works for guests in ${light ? 'light' : 'dark'} at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.5;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          FlutterSecureStorage.setMockInitialValues({
            'appearance.theme': light ? 'light' : 'dark',
          });
          final requests = <Map<String, dynamic>>[];
          final pending = Completer<http.Response>();
          final service = ChatService(
            client: ApiClient(
              httpClient: MockClient((request) async {
                expect(request.url.path, '/api/v1/chat');
                expect(request.headers.containsKey('Authorization'), isFalse);
                requests.add(jsonDecode(request.body) as Map<String, dynamic>);
                return pending.future;
              }),
            ),
          );
          await tester.pumpWidget(
            buildTestApp(initialRoute: AppRoutes.chat, chatService: service),
          );
          await pumpRoute(tester);
          expect(find.byType(ChatScreen), findsOneWidget);
          expect(
            Theme.of(tester.element(find.byType(ChatScreen))).brightness,
            light ? Brightness.light : Brightness.dark,
          );
          expect(find.byKey(const Key('loginTitle')), findsNothing);
          final send = find.byKey(const Key('sendCinemaChat'));
          expect(tester.widget<IconButton>(send).onPressed, isNull);
          await tester.enterText(
            find.byKey(const Key('cinemaChatInput')),
            'Gợi ý phim hay',
          );
          await tester.pump();
          await tester.tap(send);
          await tester.pump();
          expect(requests.single['messages'], [
            {'role': 'user', 'content': 'Gợi ý phim hay'},
          ]);
          expect(find.text('Cinema AI is thinking…'), findsOneWidget);
          expect(tester.widget<IconButton>(send).onPressed, isNull);
          pending.complete(
            http.Response(
              jsonEncode({'message': 'Bạn có thể xem Phim Kiểm Thử.'}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          );
          await pumpRoute(tester);
          expect(find.text('Bạn có thể xem Phim Kiểm Thử.'), findsOneWidget);
          expect(find.text('Gợi ý phim hay'), findsOneWidget);
          await tester.tap(find.byKey(const Key('newCinemaChat')));
          await pumpRoute(tester);
          expect(find.text('What would you like to watch?'), findsOneWidget);
          expect(find.byKey(const ValueKey('chatMessage-0')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Retry resends the failed message once and later turns keep context',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final bodies = <Map<String, dynamic>>[];
      final service = ChatService(
        client: ApiClient(
          httpClient: MockClient((request) async {
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            if (bodies.length == 1) {
              return http.Response(
                '{"detail":"Cinema AI is not configured yet."}',
                503,
              );
            }
            return http.Response(
              '{"message":"Choose a movie from Movies."}',
              200,
            );
          }),
        ),
      );
      await tester.pumpWidget(
        buildTestApp(initialRoute: AppRoutes.chat, chatService: service),
      );
      await pumpRoute(tester);
      await tester.enterText(
        find.byKey(const Key('cinemaChatInput')),
        'Help with booking',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('sendCinemaChat')));
      await pumpRoute(tester);
      expect(find.text('Cinema AI is not configured yet.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('retryCinemaChat')));
      await pumpRoute(tester);
      expect(bodies[1], bodies[0]);
      expect(find.text('Help with booking'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('cinemaChatInput')),
        'And then?',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('sendCinemaChat')));
      await pumpRoute(tester);
      expect(
        (bodies.last['messages'] as List).map(
          (dynamic message) => message['role'],
        ),
        ['user', 'assistant', 'user'],
      );
      expect(find.byKey(const Key('cinemaChatError')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home launcher opens the chatbot and browser back restores home',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(buildTestApp());
      await pumpRoute(tester);
      await tester.tap(find.byKey(const Key('openCinemaChat')));
      await pumpRoute(tester);
      expect(find.byType(ChatScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(ChatScreen))).pop();
      await pumpRoute(tester);
      expect(find.byKey(const Key('openCinemaChat')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Long sessions retain only complete turns within request limits',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final bodies = <List<dynamic>>[];
      final service = ChatService(
        client: ApiClient(
          httpClient: MockClient((request) async {
            bodies.add(
              (jsonDecode(request.body) as Map<String, dynamic>)['messages']
                  as List,
            );
            return http.Response(
              jsonEncode({'message': 'Movie advice. ' * 250}),
              200,
            );
          }),
        ),
      );
      await tester.pumpWidget(
        buildTestApp(initialRoute: AppRoutes.chat, chatService: service),
      );
      await pumpRoute(tester);
      for (var i = 0; i < 8; i++) {
        await tester.enterText(
          find.byKey(const Key('cinemaChatInput')),
          'Next idea $i',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('sendCinemaChat')));
        await pumpRoute(tester);
      }
      expect(bodies.length, 8);
      for (final messages in bodies) {
        expect(messages.length, lessThanOrEqualTo(11));
        expect(messages.first['role'], 'user');
        expect(messages.last['role'], 'user');
        expect(
          messages.fold<int>(
            0,
            (sum, dynamic message) =>
                sum + (message['content'] as String).length,
          ),
          lessThanOrEqualTo(12000),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  test('Malformed API reply surfaces an error instead of an empty assistant message', () async {
    final service = ChatService(
      client: ApiClient(
        httpClient: MockClient(
          (_) async => http.Response('{"message":" "}', 200),
        ),
      ),
    );
    await expectLater(
      service.reply([const ChatMessage(role: 'user', content: 'Hello')]),
      throwsException,
    );
  });
}
