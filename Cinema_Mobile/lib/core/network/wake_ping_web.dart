import 'dart:js_interop';

import 'package:web/web.dart' as web;

// Browser: the services send no CORS headers (only the gateway does), so ask
// for an opaque answer. The request still reaches the service and wakes it,
// without a CORS error in the console.
Future<void> wakePing(Uri url) async {
  try {
    await web.window
        .fetch(
          url.toString().toJS,
          web.RequestInit(mode: 'no-cors', cache: 'no-store'),
        )
        .toDart;
  } on Object {
    // Still starting or unreachable: the next ping or retry takes over.
  }
}
