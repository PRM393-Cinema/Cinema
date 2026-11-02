import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'wake_ping.dart';

// On free hosting (Render) every service sleeps after 15 minutes without
// requests and takes up to a minute to start again. A request the gateway
// forwards does not wake a sleeping service, but a request from the browser or
// the phone does. So the app pings each service's health page directly when it
// starts, and the API client keeps retrying while the services start.
// Configured with --dart-define=WAKE_UP_URLS=https://…/health,https://…/health;
// without it (a local backend) nothing is pinged or retried.
class ServerWakeUp {
  ServerWakeUp({
    required this.urls,
    Future<void> Function(Uri url)? ping,
    this.retryDelays = defaultRetryDelays,
    this.maxWait = const Duration(seconds: 90),
    this.pingInterval = const Duration(seconds: 30),
  }) : _ping = ping ?? wakePing;

  // About a minute of retries: a sleeping service usually starts in 25-50 s.
  static const defaultRetryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 10),
    Duration(seconds: 10),
    Duration(seconds: 15),
  ];

  static final ServerWakeUp? configured = ApiConfig.wakeUpUrls.isEmpty
      ? null
      : ServerWakeUp(urls: ApiConfig.wakeUpUrls);

  final List<Uri> urls;
  final List<Duration> retryDelays;

  // Stop retrying after this long, even if delays are left (each attempt can
  // also wait for the request timeout).
  final Duration maxWait;

  // Pings at most this often, however many requests are waiting.
  final Duration pingInterval;

  final Future<void> Function(Uri url) _ping;
  DateTime? _lastPing;

  // Requests waiting for a service to start; the app shows a notice meanwhile.
  final waiting = ValueNotifier<int>(0);

  void wake() {
    final now = DateTime.now();
    final last = _lastPing;
    if (last != null && now.difference(last) < pingInterval) return;
    _lastPing = now;

    for (final url in urls) {
      // The answer does not matter: the request alone starts the service.
      unawaited(_ping(url).catchError((Object _) {}));
    }
  }
}
