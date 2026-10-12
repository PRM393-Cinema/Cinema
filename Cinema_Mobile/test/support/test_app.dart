import 'package:cinema_fe/app/app.dart';
import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/session/session_state.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/repositories/auth_repository.dart';
import 'package:cinema_fe/data/repositories/booking_repository.dart';
import 'package:cinema_fe/data/repositories/catalog_repository.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:cinema_fe/features/payment/payment_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'fixtures.dart';

Widget buildTestApp({
  AuthRepository? authRepository,
  CatalogRepository? catalogRepository,
  BookingRepository? bookingRepository,
  StaffService? staffService,
  SessionState? session,
  bool authenticated = false,
  AuthUser? user,
  String initialRoute = AppRoutes.home,
  PayOsReturn? paymentReturn,
}) {
  final sessionState = session ?? SessionState();
  if (authenticated) {
    sessionState.setAuthenticated(user ?? customerUser);
  } else {
    sessionState.setGuest();
  }

  return SessionProvider(
    sessionState: sessionState,
    child: CinemaApp(
      authRepository: authRepository ?? FakeAuthRepository(),
      catalogRepository: catalogRepository ?? FakeCatalogRepository(),
      bookingRepository: bookingRepository ?? FakeBookingRepository(),
      staffService: staffService,
      initialRoute: initialRoute,
      paymentReturn: paymentReturn,
    ),
  );
}

Future<void> pumpRoute(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

// The payment screen ticks every second, so pumpAndSettle never settles
// while it is visible.
Future<void> pumpFrames(
  WidgetTester tester, {
  Duration duration = const Duration(milliseconds: 600),
}) async {
  await tester.pump();
  await tester.pump(duration);
}

// The home list builds its items lazily, so a `.first` finder for a card
// below the fold has nothing to evaluate (and throws) until the list scrolls.
Future<void> scrollHomeTo(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(
        of: find.byKey(const Key('homeScrollView')),
        matching: find.byType(Scrollable),
      )
      .first;
  for (var step = 0; step < 50 && !_isBuilt(finder); step++) {
    await tester.drag(scrollable, const Offset(0, -240));
    await tester.pump();
  }
  await tester.ensureVisible(finder);
  await tester.pump();
}

bool _isBuilt(Finder finder) {
  try {
    return finder.evaluate().isNotEmpty;
  } on StateError {
    return false;
  }
}
