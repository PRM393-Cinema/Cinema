// Printing a ticket at the counter needs a browser; the phone app shows the
// QR code on screen instead.
export 'ticket_print_stub.dart'
    if (dart.library.js_interop) 'ticket_print_web.dart';
