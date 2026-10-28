import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/data/models/loyalty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/test_app.dart';

class _Points extends FakeBookingRepository {
  bool fail = true;
  @override
  Future<LoyaltyCard> getMyLoyalty() async {
    if (fail) throw Exception('Offline');
    return const LoyaltyCard(userId: 1, points: 0, tier: MemberTier.member);
  }
}

void main() {
  testWidgets('Direct point history requires login', (tester) async {
    await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.pointHistory));
    await pumpRoute(tester);
    expect(find.byKey(const Key('loginTitle')), findsOneWidget);
  });
  testWidgets('History retries a failed request and shows empty state', (
    tester,
  ) async {
    final repo = _Points();
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        bookingRepository: repo,
        initialRoute: AppRoutes.pointHistory,
      ),
    );
    await pumpRoute(tester);
    expect(find.text('Unable to load point history'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Retry'));
    await pumpRoute(tester);
    expect(find.text('No point activity yet'), findsOneWidget);
    expect(find.text('0 points'), findsOneWidget);
  });
  for (final size in [const Size(375, 812), const Size(812, 375)]) {
    testWidgets('Point history opens related booking at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final repo = FakeBookingRepository()
        ..loyalty = LoyaltyCard(
          userId: 1,
          points: 50,
          tier: MemberTier.member,
          history: [
            LoyaltyLine(
              id: 1,
              type: 'EARN',
              points: 50,
              bookingId: 101,
              note: 'BK-TEST-001',
              createdAt: DateTime(2026, 10, 29),
            ),
          ],
        );
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: repo,
          initialRoute: AppRoutes.pointHistory,
        ),
      );
      await pumpRoute(tester);
      expect(find.text('+50'), findsOneWidget);
      await tester.ensureVisible(find.text('View booking'));
      await pumpRoute(tester);
      await tester.tap(find.text('View booking'));
      await pumpRoute(tester);
      expect(find.text('Booking Detail'), findsOneWidget);
      await tester.pageBack();
      await pumpRoute(tester);
      expect(find.text('+50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
