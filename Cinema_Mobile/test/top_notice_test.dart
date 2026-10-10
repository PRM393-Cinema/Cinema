import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/core/widgets/top_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Notice fits mobile safe area, replaces the old notice and hides itself',
    (tester) async {
      tester.view.physicalSize = const Size(412, 924);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 30);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      var count = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(412, 924),
              padding: EdgeInsets.only(top: 30),
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showTopNotice(
                      Overlay.of(context),
                      'Thông báo ${++count}: Vai trò tài khoản đã thay đổi. Vui lòng đăng nhập lại.',
                    ),
                    child: const Text('Show notice'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show notice'));
      await tester.pumpAndSettle();
      final notice = find.byKey(const Key('topNotice'));
      expect(notice, findsOneWidget);
      final bounds = tester.getRect(notice);
      expect(bounds.top, greaterThanOrEqualTo(46));
      expect(bounds.bottom, lessThan(180));
      expect(bounds.left, greaterThanOrEqualTo(16));
      expect(bounds.right, lessThanOrEqualTo(396));
      expect(find.byType(Dialog), findsNothing);

      await tester.tap(find.text('Show notice'));
      await tester.pumpAndSettle();
      expect(notice, findsOneWidget);
      expect(find.textContaining('Thông báo 1:'), findsNothing);
      expect(find.textContaining('Thông báo 2:'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(notice, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
