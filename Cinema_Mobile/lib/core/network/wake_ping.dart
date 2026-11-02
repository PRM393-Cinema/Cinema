// A request that wakes a sleeping service: fetch() in the browser, a plain GET
// on phones and desktop.
export 'wake_ping_io.dart' if (dart.library.js_interop) 'wake_ping_web.dart';
