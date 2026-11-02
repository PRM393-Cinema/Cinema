import 'dart:async';
import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/network/server_wake_up.dart';
import 'package:cinema_fe/core/widgets/cinema_account_widgets.dart';
import 'package:cinema_fe/data/services/chat_service.dart';
import 'package:cinema_fe/features/chat/widgets/chat_panel.dart';
import 'package:cinema_fe/features/home/screens/home_screen.dart';
import 'package:cinema_fe/app/customer_frame.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/test_app.dart';

Future<void> openChat(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('openCinemaChat')));
  await pumpRoute(tester);
}

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

  for (final width in [390.0, 1440.0]) {
    for (final route in [
      AppRoutes.home,
      AppRoutes.myBookings,
      AppRoutes.myRatings,
      AppRoutes.notifications,
      AppRoutes.paymentHistory,
      AppRoutes.profile,
      AppRoutes.movieDetail(1),
      AppRoutes.login,
    ]) {
      testWidgets('Global chat stays on $route at $width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          buildTestApp(
            initialRoute: route,
            authenticated: route != AppRoutes.login,
          ),
        );
        await pumpRoute(tester);
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        final tracker = navigator.widget.observers
            .whereType<RouteTracker>()
            .single;
        final before = tracker.current.value;
        expect(find.byKey(const Key('openCinemaChat')), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const Key('cinemaChatLauncherSize'))),
          const Size(56, 56),
        );
        await openChat(tester);
        expect(tracker.current.value, before);
        expect(
          tester.getRect(find.byKey(const Key('cinemaChatPanel'))).right,
          lessThanOrEqualTo(width),
        );
        await tester.tap(find.byKey(const Key('closeCinemaChat')));
        await pumpRoute(tester);
        expect(find.byType(ChatPanel), findsNothing);
        expect(tracker.current.value, before);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Launcher expands on hover and keyboard focus, then collapses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTestApp());
    await pumpRoute(tester);
    final launcher = find.byKey(const Key('cinemaChatLauncherSize'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(launcher));
    await pumpRoute(tester);
    expect(tester.getSize(launcher).width, greaterThan(56));
    expect(find.text('Cinema AI'), findsOneWidget);
    await mouse.moveTo(const Offset(10, 120));
    await pumpRoute(tester);
    expect(tester.getSize(launcher).width, 56);
    final button = tester.widget<InkWell>(
      find.byKey(const Key('openCinemaChat')),
    );
    button.focusNode!.requestFocus();
    await pumpRoute(tester);
    expect(tester.getSize(launcher).width, greaterThan(56));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await pumpRoute(tester);
    expect(find.byType(ChatPanel), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpRoute(tester);
    expect(find.byType(ChatPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Minimizing and changing pages preserves an in-flight reply', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final reply = Completer<http.Response>();
    final service = ChatService(
      client: ApiClient(httpClient: MockClient((_) => reply.future)),
    );
    await tester.pumpWidget(
      buildTestApp(authenticated: true, chatService: service),
    );
    await pumpRoute(tester);
    await openChat(tester);
    await tester.enterText(
      find.byKey(const Key('cinemaChatInput')),
      'A movie recommendation',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('sendCinemaChat')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('closeCinemaChat')));
    await pumpRoute(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('webHeader')),
        matching: find.text('Ratings'),
      ),
    );
    await pumpRoute(tester);
    reply.complete(http.Response('{"message":"Try a comedy."}', 200));
    await pumpRoute(tester);
    await openChat(tester);
    expect(find.text('A movie recommendation'), findsOneWidget);
    expect(find.text('Try a comedy.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile keyboard leaves the composer and close control visible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTestApp());
    await pumpRoute(tester);
    final launcher = tester.getRect(find.byKey(const Key('openCinemaChat')));
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Open Cinema AI chat'))
          .rect
          .size,
      const Size(56, 56),
    );
    final nav = tester.getRect(find.byType(CinemaNavigationBar));
    expect(launcher.bottom, lessThanOrEqualTo(nav.top));
    await openChat(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await pumpRoute(tester);
    expect(
      tester.getRect(find.byKey(const Key('cinemaChatInput'))).bottom,
      lessThanOrEqualTo(544),
    );
    expect(
      tester.getRect(find.byKey(const Key('closeCinemaChat'))).top,
      greaterThanOrEqualTo(0),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

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
          await tester.pumpWidget(buildTestApp(chatService: service));
          await pumpRoute(tester);
          await openChat(tester);
          expect(find.byType(ChatPanel), findsOneWidget);
          expect(
            Theme.of(tester.element(find.byType(ChatPanel))).brightness,
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
          await tester.drag(
            find.byKey(const Key('cinemaChatMessages')),
            const Offset(0, 300),
          );
          await pumpRoute(tester);
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
      await tester.pumpWidget(buildTestApp(chatService: service));
      await pumpRoute(tester);
      await openChat(tester);
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
    'Floating chat keeps the current page when opened and minimized',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(buildTestApp());
      await pumpRoute(tester);
      await openChat(tester);
      expect(find.byType(ChatPanel), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(HomeScreen)))!.settings.name,
        AppRoutes.home,
      );
      expect(
        tester.getSize(find.byKey(const Key('cinemaChatPanel'))).width,
        400,
      );
      await tester.tap(find.byKey(const Key('closeCinemaChat')));
      await pumpRoute(tester);
      expect(find.byKey(const Key('openCinemaChat')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('cinemaChatLauncherSize'))).width,
        56,
      );
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
      await tester.pumpWidget(buildTestApp(chatService: service));
      await pumpRoute(tester);
      await openChat(tester);
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
