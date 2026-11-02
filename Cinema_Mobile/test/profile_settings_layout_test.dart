import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/session/session_state.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/core/widgets/cinema_background.dart';
import 'package:cinema_fe/app/theme/theme_switch.dart';
import 'package:cinema_fe/data/models/loyalty.dart';
import 'package:cinema_fe/features/profile/widgets/membership_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/test_app.dart';

LoyaltyCard _card({MemberTier tier = MemberTier.vvip}) => LoyaltyCard(
  userId: 3,
  points: 194,
  tier: tier,
  lifetimeSpend: 500000,
  earnRatePercent: 10,
  giftTickets: 2,
  giftCombos: 1,
  giftRenewsAt: DateTime(2027, 5, 1),
  nextTier: tier == MemberTier.member ? MemberTier.vip : null,
  nextTierSpend: tier == MemberTier.member ? 2000000 : null,
);

void main() {
  for (final theme in ['light', 'dark']) {
    for (final (size, scale) in [
      (const Size(900, 900), 1.0),
      (const Size(1440, 900), 1.0),
      (const Size(1920, 900), 1.0),
      (const Size(900, 900), 1.5),
      (const Size(375, 844), 1.0),
      (const Size(844, 390), 1.0),
      (const Size(375, 844), 1.5),
    ]) {
      testWidgets('$theme settings adapt to $size at $scale', (tester) async {
        FlutterSecureStorage.setMockInitialValues({'appearance.theme': theme});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpWidget(
          buildTestApp(
            authenticated: true,
            initialRoute: AppRoutes.profile,
            bookingRepository: FakeBookingRepository()..loyalty = _card(),
          ),
        );
        await pumpRoute(tester);
        final sidebar = tester.getRect(
          find.byKey(const Key('accountSettingsSidebar')),
        );
        final profile = tester.getRect(
          find.byKey(const Key('accountProfileGrid')),
        );
        expect(find.byType(CinemaBackdropTransition), findsOneWidget);
        if (size.width >= 900) {
          expect(
            Theme.of(tester.element(find.byType(Scaffold).last))
                .scaffoldBackgroundColor,
            Colors.transparent,
          );
        }
        expect(
          tester.getSize(find.byKey(const Key('editProfile'))).height,
          greaterThanOrEqualTo(44),
        );
        expect(find.text('194 points'), findsOneWidget);
        expect(find.text('VVIP'), findsOneWidget);
        expect(
          find.text('2 ticket(s) of your choice · 1 combo(s)'),
          findsOneWidget,
        );
        expect(find.text('You are at the top tier.'), findsOneWidget);
        if (size.width >= 900) {
          expect(sidebar.right, lessThan(profile.left));
          expect(sidebar.top, profile.top);
          final name = tester.getRect(find.text('Full name'));
          final email = tester.getRect(find.text('Email'));
          expect(name.top, email.top);
          expect(email.left, greaterThan(name.right));
          if (scale == 1) {
            expect(
              tester.getRect(find.byKey(const Key('membershipCard'))).bottom,
              lessThan(900),
            );
            expect(sidebar.bottom, lessThan(900));
          }
        } else {
          expect(sidebar.bottom, lessThan(profile.top));
          expect(
            tester.getRect(find.text('Email')).top,
            greaterThan(tester.getRect(find.text('Full name')).bottom),
          );
        }
        final history = find.byKey(const Key('pointHistory'));
        await tester.ensureVisible(history);
        await pumpRoute(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(history);
        await pumpRoute(tester);
        expect(find.text('Point history'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      '$theme sidebar routes, keyboard focus and sign out stay functional',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({'appearance.theme': theme});
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final auth = FakeAuthRepository();
        final session = SessionState();
        await tester.pumpWidget(
          buildTestApp(
            authenticated: true,
            initialRoute: AppRoutes.profile,
            authRepository: auth,
            session: session,
            bookingRepository: FakeBookingRepository()
              ..loyalty = _card(tier: MemberTier.member),
          ),
        );
        await pumpRoute(tester);
        expect(find.text('${formatVnd(1500000)} to VIP'), findsOneWidget);
        for (final (label, route) in [
          ('Payment history', AppRoutes.paymentHistory),
          ('My bookings', AppRoutes.myBookings),
          ('Notifications', AppRoutes.notifications),
        ]) {
          final link = find.descendant(
            of: find.byKey(const Key('accountSettingsSidebar')),
            matching: find.widgetWithText(TextButton, label),
          );
          final context = tester.element(link);
          final navigator = Navigator.of(context);
          await tester.tap(link);
          await pumpRoute(tester);
          expect(
            ModalRoute.of(tester.element(find.byType(Scaffold).last))
                ?.settings
                .name,
            route,
          );
          navigator.pop();
          await pumpRoute(tester);
        }
        final edit = find.byKey(const Key('editProfile'));
        Focus.of(
          tester.element(
            find.descendant(of: edit, matching: find.text('Edit profile')),
          ),
        ).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await pumpRoute(tester);
        expect(find.byKey(const Key('saveProfile')), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await pumpRoute(tester);
        await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
        await pumpRoute(tester);
        await tester.tap(find.text('Stay signed in'));
        await pumpRoute(tester);
        expect(auth.logoutCalls, 0);
        await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
        await pumpRoute(tester);
        await tester.tap(find.widgetWithText(TextButton, 'Sign out').last);
        await pumpRoute(tester);
        expect(auth.logoutCalls, 1);
        expect(session.isAuthenticated, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Switching theme keeps settings geometry and the existing account state',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({'appearance.theme': 'dark'});
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          initialRoute: AppRoutes.profile,
          bookingRepository: FakeBookingRepository()..loyalty = _card(),
        ),
      );
      await pumpRoute(tester);
      final keys = [
        'accountSettingsSidebar',
        'accountProfileGrid',
        'membershipCard',
        'editProfile',
        'changePassword',
      ];
      final before = {
        for (final key in keys) key: tester.getRect(find.byKey(Key(key))),
      };
      await tester.tap(find.byType(ThemeSwitch));
      await pumpRoute(tester);
      for (final key in keys) {
        expect(tester.getRect(find.byKey(Key(key))), before[key]);
      }
      expect(
        tester.widget<MembershipCard>(find.byType(MembershipCard)).compact,
        isTrue,
      );
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('194 points'), findsOneWidget);
      expect(find.byType(CinemaBackdropTransition), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
