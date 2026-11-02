import 'dart:convert';

import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/network/api_exception.dart';
import 'package:cinema_fe/core/network/server_wake_up.dart';
import 'package:cinema_fe/core/widgets/server_starting_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _services = [
  Uri.parse('https://auth.example/health'),
  Uri.parse('https://movie.example/health'),
];

// The backend answers with [answers] in turn (a status code, or 0 to drop the
// connection) and then 200.
class _Backend {
  _Backend(this.answers);

  final List<int> answers;
  final requests = <http.Request>[];
  final pinged = <Uri>[];

  late final wakeUp = ServerWakeUp(
    urls: _services,
    ping: (url) async => pinged.add(url),
    retryDelays: List.filled(4, Duration.zero),
  );

  ApiClient client({bool wake = true}) => ApiClient(
    baseUrl: 'https://gateway.example',
    wakeUp: wake ? wakeUp : null,
    httpClient: MockClient((request) async {
      requests.add(request);
      final index = requests.length - 1;
      final answer = index < answers.length ? answers[index] : 200;
      if (answer == 0) throw http.ClientException('Connection closed');
      return http.Response(
        jsonEncode(answer == 200 ? {'ok': true} : {'title': 'Unavailable'}),
        answer,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}

void main() {
  test('A read waits for sleeping services, waking them once', () async {
    final backend = _Backend([503, 502, 504]);
    final client = backend.client();

    expect(await client.get('/api/v1/movies'), {'ok': true});
    expect(backend.requests, hasLength(4));
    // Pinged once per interval, however many attempts.
    expect(backend.pinged, _services);
    expect(backend.wakeUp.waiting.value, 0);
  });

  test('A read also retries when the gateway does not answer', () async {
    final backend = _Backend([0]);

    expect(await backend.client().get('/api/v1/movies'), {'ok': true});
    expect(backend.requests, hasLength(2));
  });

  test('A write is repeated only when no service received it (503)', () async {
    final unavailable = _Backend([503]);
    expect(await unavailable.client().post('/api/v1/auth/login'), {'ok': true});
    expect(unavailable.requests, hasLength(2));

    // A 502 may come after the service handled the request: do not book twice.
    final badGateway = _Backend([502]);
    await expectLater(
      badGateway.client().post('/api/v1/bookings'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 502)),
    );
    expect(badGateway.requests, hasLength(1));

    final dropped = _Backend([0]);
    await expectLater(
      dropped.client().post('/api/v1/bookings'),
      throwsA(isA<ApiException>()),
    );
    expect(dropped.requests, hasLength(1));
  });

  test('Gives up after the last retry and reports the error', () async {
    final backend = _Backend(List.filled(10, 503));

    await expectLater(
      backend.client().get('/api/v1/movies'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
    );
    expect(backend.requests, hasLength(5));
    expect(backend.wakeUp.waiting.value, 0);
  });

  test('Without wake-up (local backend) errors show at once', () async {
    final backend = _Backend([503]);

    await expectLater(
      backend.client(wake: false).get('/api/v1/movies'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
    );
    expect(backend.requests, hasLength(1));
    expect(backend.pinged, isEmpty);
  });

  test('Ordinary errors are not retried', () async {
    final backend = _Backend([404]);

    await expectLater(
      backend.client().get('/api/v1/movies/99'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
    expect(backend.requests, hasLength(1));
    expect(backend.pinged, isEmpty);
  });

  test('wake() pings every service at most once per interval', () {
    final pinged = <Uri>[];
    final wakeUp = ServerWakeUp(
      urls: _services,
      ping: (url) async => pinged.add(url),
    );

    wakeUp.wake();
    wakeUp.wake();
    expect(pinged, _services);
  });

  testWidgets('The notice shows while requests wait', (tester) async {
    final wakeUp = ServerWakeUp(urls: _services, ping: (_) async {});
    await tester.pumpWidget(
      MaterialApp(
        home: ServerStartingNotice(
          wakeUp: wakeUp,
          child: const Scaffold(body: Text('Page')),
        ),
      ),
    );
    expect(find.byKey(const Key('serverStartingNotice')), findsNothing);

    wakeUp.waiting.value = 1;
    await tester.pump();
    expect(find.byKey(const Key('serverStartingNotice')), findsOneWidget);
    expect(find.text('Page'), findsOneWidget);

    wakeUp.waiting.value = 0;
    await tester.pump();
    expect(find.byKey(const Key('serverStartingNotice')), findsNothing);
  });
}
