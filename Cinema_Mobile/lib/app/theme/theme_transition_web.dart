import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

bool get usesBrowserThemeTransition => web.document.has('startViewTransition');

void transitionTheme(VoidCallback update, {required bool animate}) {
  if (!animate || !usesBrowserThemeTransition) {
    update();
    return;
  }
  // The browser fades snapshots; Flutter builds the new theme just once.
  final transition = web.document.startViewTransition(
    (() {
      update();
      // View transitions pause vsync while waiting for the new canvas contents.
      WidgetsBinding.instance.scheduleWarmUpFrame();
      return WidgetsBinding.instance.endOfFrame.then((_) => null).toJS;
    }).toJS,
  );
  // Resizing or another toggle can skip the animation without losing the update.
  unawaited(transition.ready.toDart.then<void>((_) {}, onError: (Object _) {}));
}
