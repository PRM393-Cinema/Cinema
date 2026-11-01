import 'package:cinema_fe/app/session_app.dart';
import 'package:cinema_fe/core/session/session_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Mobile hides scrollbars while desktop keeps them and both scroll',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      for (final width in [390.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 844);
        await tester.pumpWidget(const SizedBox());
        final session = SessionState()..setGuest();
        final controller = ScrollController();
        final page = Scaffold(
          body: ListView.builder(
            controller: controller,
            itemCount: 100,
            itemExtent: 60,
            itemBuilder: (_, index) => Text('Item $index'),
          ),
        );
        await tester.pumpWidget(
          SessionProvider(
            sessionState: session,
            child: SessionApp(
              title: 'Scroll test',
              onGenerateRoute: (_) =>
                  MaterialPageRoute<void>(builder: (_) => page),
              onGenerateInitialRoutes: (_) => [
                MaterialPageRoute<void>(builder: (_) => page),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(Scrollbar),
          width < 900 ? findsNothing : findsOneWidget,
        );
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(0));
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        session.dispose();
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
