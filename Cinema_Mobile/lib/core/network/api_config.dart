import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  // Override with --dart-define=API_BASE_URL=http://192.168.x.x:5000 when the
  // backend runs on another machine or the app runs on a physical phone.
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  // Override with --dart-define=PAYMENT_RETURN_URL=https://... to send the
  // browser to a custom page after a PayOS payment.
  static const String _paymentReturnUrlOverride = String.fromEnvironment(
    'PAYMENT_RETURN_URL',
  );

  // The Android emulator reaches the host machine through 10.0.2.2, while web,
  // desktop and the iOS simulator share localhost with the backend.
  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) {
      return _withoutTrailingSlash(_baseUrlOverride);
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }

    return 'http://localhost:5000';
  }

  // Where PayOS sends the browser after the customer pays or cancels. On web
  // this is the app itself, which then verifies the payment from the PayOS
  // query parameters. Elsewhere the app verifies when the user comes back.
  static String get paymentReturnUrl {
    if (_paymentReturnUrlOverride.isNotEmpty) {
      return _paymentReturnUrlOverride;
    }

    if (kIsWeb) {
      final current = Uri.base;
      return Uri(
        scheme: current.scheme,
        host: current.host,
        port: current.port,
        path: current.path,
      ).toString();
    }

    return '$baseUrl/';
  }

  static String _withoutTrailingSlash(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
