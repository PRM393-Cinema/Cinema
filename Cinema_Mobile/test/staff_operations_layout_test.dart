import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/widgets/cinema_background.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:cinema_fe/features/staff/screens/staff_record_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fixtures.dart';
import 'support/test_app.dart';

Map<String, Object?> _record(String kind, int index) => switch (kind) {
  'Bookings' => {
    'id': index + 1,
    'bookingCode': 'BK-20261101225826-30520$index',
    'showtimeId': 11,
    'movieTitle': 'Oppenheimer',
    'status': ['CONFIRMED', 'CANCELLED', 'REFUND_PENDING'][index % 3],
    'totalAmount': 264000,
    'createdAt': '2026-11-01T22:59:00',
    'seats': <Object?>[],
  },
  'Showtimes' => {
    'id': index + 1,
    'movieId': 1,
    'roomId': 1,
    'startTime': '2026-11-02T16:00:00',
    'endTime': '2026-11-02T18:00:00',
    'price': 120000,
    'status': 'OPEN',
    'format': 'IMAX',
  },
  'Rooms' => {
    'id': index + 1,
    'name': 'Cinema room ${index + 1}',
    'totalSeats': 60,
  },
  'Payments' => {
    'id': index + 1,
    'paymentCode': 'PAY-20261101225943-15901$index',
    'bookingId': 1,
    'amount': 264000,
    'method': 'PAYOS',
    'status': ['SUCCESS', 'FAILED', 'REFUND_PENDING'][index % 3],
    'createdAt': '2026-11-01T22:59:00',
  },
  _ => {
    'id': index + 1,
    'refundCode': 'RF-20261102011138-83574$index',
    'paymentId': 1,
    'bookingId': 1,
    'amount': 264000,
    'status': ['PENDING', 'COMPLETED', 'REJECTED'][index % 3],
    'createdAt': '2026-11-02T01:11:00',
  },
};

StaffService _service(List<Uri> calls, {bool Function()? fail}) => StaffService(
  client: ApiClient(
    httpClient: MockClient((request) async {
      calls.add(request.url);
      if (fail?.call() == true) {
        return http.Response('Service unavailable', 503);
      }
      final path = request.url.path;
      final kind = path.contains('refunds')
          ? 'Refunds'
          : path.contains('payments')
          ? 'Payments'
          : path.contains('showtimes')
          ? 'Showtimes'
          : path.contains('rooms')
          ? 'Rooms'
          : 'Bookings';
      if (RegExp(r'/\d+$').hasMatch(path) && !path.contains('status')) {
        return http.Response(jsonEncode(_record(kind, 0)), 200);
      }
      final page = int.parse(
        request.url.queryParameters['page'] ??
            request.url.queryParameters['pageNumber'] ??
            '1',
      );
      return http.Response(
        jsonEncode({
          'items': [
            for (var index = 0; index < 3; index++) _record(kind, index),
          ],
          'pageNumber': page,
          'totalPages': 2,
          'totalCount': 13,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  ),
);

Future<void> _open(
  WidgetTester tester,
  StaffService service,
  Size size,
  String theme, {
  double scale = 1,
}) async {
  FlutterSecureStorage.setMockInitialValues({'appearance.theme': theme});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    buildAdminTestApp(
      authenticated: true,
      user: AuthUser.fromJson({
        ...customerUser.toJson(),
        'roles': ['ROLE_STAFF'],
      }),
      staffService: service,
      initialRoute: AppRoutes.staffOperations,
    ),
  );
  await pumpRoute(tester);
}

Future<void> _tab(WidgetTester tester, String label) async {
  final tab = find.byKey(ValueKey('operationsTab-$label'));
  if (tab.evaluate().isEmpty) {
    await tester.drag(find.byType(ListView).last, const Offset(0, 2000));
    await pumpRoute(tester);
  }
  await tester.ensureVisible(tab);
  await pumpRoute(tester);
  await tester.tap(tab);
  await pumpRoute(tester);
}

void main() {
  for (final theme in ['dark', 'light']) {
    for (final (size, scale) in [
      (const Size(900, 1000), 1.0),
      (const Size(1440, 1000), 1.0),
      (const Size(1920, 1000), 1.0),
      (const Size(1100, 1000), 1.5),
      (const Size(375, 844), 1.0),
      (const Size(844, 390), 1.0),
      (const Size(375, 844), 1.5),
      (const Size(375, 844), 3.2),
    ]) {
      testWidgets('Operations all sections fit $theme $size/$scale', (
        tester,
      ) async {
        final calls = <Uri>[];
        await _open(tester, _service(calls), size, theme, scale: scale);
        expect(find.byType(CinemaBackdropTransition), findsOneWidget);
        if (size.width >= 900 && scale == 1) {
          final controls = [
            tester.getRect(find.byKey(const Key('operationsLookup'))),
            tester.getRect(find.byType(DropdownButtonFormField<String>)),
            tester.getRect(find.byKey(const Key('operationsDates'))),
            tester.getRect(find.byKey(const Key('operationsCreate'))),
          ];
          for (final control in controls) {
            expect(control.center.dy, closeTo(controls.first.center.dy, 1));
          }
          expect(controls.last.width, lessThanOrEqualTo(160));
        }
        for (final (section, count) in [
          ('Bookings', 6),
          ('Showtimes', 7),
          ('Rooms', 4),
          ('Payments', 7),
          ('Refunds', 6),
        ]) {
          if (section != 'Bookings') await _tab(tester, section);
          if (size.width >= 900) {
            final table = tester.widget<DataTable>(
              find.byKey(const Key('operationsTable')),
            );
            expect(table.columns.length, count);
            expect(table.rows.length, 3);
            expect(table.dataRowMinHeight, 56 * scale);
            expect(find.text('View'), findsNWidgets(3));
          } else {
            expect(find.byType(DataTable), findsNothing);
            if (find.byType(ListTile).evaluate().isEmpty) {
              await tester.drag(
                find.byType(ListView).last,
                const Offset(0, -500),
              );
              await pumpRoute(tester);
            }
            expect(find.byType(ListTile), findsNWidgets(3));
          }
          expect(tester.takeException(), isNull, reason: section);
        }
      });
    }
  }

  testWidgets(
    'Operations preserves server filters, paging, lookup and detail links',
    (tester) async {
      final calls = <Uri>[];
      await _open(tester, _service(calls), const Size(1440, 1100), 'dark');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await pumpRoute(tester);
      await tester.tap(find.text('Refund pending').last);
      await pumpRoute(tester);
      expect(calls.last.path, '/api/v1/bookings/status/REFUND_PENDING');
      await tester.ensureVisible(find.byKey(const Key('operationsNext')));
      await tester.tap(find.byKey(const Key('operationsNext')));
      await pumpRoute(tester);
      expect(calls.last.queryParameters['page'], '2');
      expect(calls.last.path, '/api/v1/bookings/status/REFUND_PENDING');
      final pageTwo = tester.widget<TextButton>(
        find.byKey(const Key('operationsNext')),
      );
      expect(pageTwo.onPressed, isNull);
      await tester.tap(find.byKey(const Key('operationsPrevious')));
      await pumpRoute(tester);
      expect(calls.last.queryParameters['page'], '1');
      await _tab(tester, 'Rooms');
      final field = find.descendant(
        of: find.byKey(const Key('operationsLookup')),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(field, ' Cinema ');
      await tester.tap(find.byTooltip('Search rooms'));
      await pumpRoute(tester);
      expect(calls.last.path, '/api/rooms/search');
      expect(calls.last.queryParameters['keyword'], 'Cinema');
      await _tab(tester, 'Refunds');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await pumpRoute(tester);
      await tester.tap(find.text('Rejected').last);
      await pumpRoute(tester);
      expect(calls.last.queryParameters['status'], 'REJECTED');
      await _tab(tester, 'Bookings');
      await tester.enterText(field, 'not-an-id');
      await tester.tap(find.byTooltip('Open booking'));
      await pumpRoute(tester);
      expect(find.text('Enter a valid booking ID.'), findsOneWidget);
      await tester.enterText(field, '1');
      await tester.tap(find.byTooltip('Open booking'));
      await pumpRoute(tester);
      expect(
        tester.widget<StaffRecordScreen>(find.byType(StaffRecordScreen)).id,
        1,
      );
      Navigator.of(tester.element(find.byType(StaffRecordScreen))).pop();
      await pumpRoute(tester);
      expect(find.byKey(const Key('operationsTable')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Date filters and retry keep the existing server requests', (
    tester,
  ) async {
    final calls = <Uri>[];
    var fail = true;
    await _open(
      tester,
      _service(calls, fail: () => fail),
      const Size(1440, 1100),
      'light',
    );
    expect(find.text('Unable to load'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await pumpRoute(tester);
    expect(find.byKey(const Key('operationsTable')), findsOneWidget);
    for (final section in ['Bookings', 'Showtimes']) {
      if (section == 'Showtimes') await _tab(tester, section);
      await tester.tap(find.byKey(const Key('operationsDates')));
      await pumpRoute(tester);
      await tester.tap(find.byTooltip('Switch to input'));
      await pumpRoute(tester);
      final fields = find.descendant(
        of: find.byType(DateRangePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '11/1/2026');
      await tester.enterText(fields.at(1), '11/3/2026');
      await tester.tap(find.text('OK'));
      await pumpRoute(tester);
      expect(
        calls.last.path,
        section == 'Bookings'
            ? '/api/v1/bookings/date-range'
            : '/api/showtimes/date-range',
      );
      expect(calls.last.queryParameters['start'], '2026-11-01T00:00:00.000');
      expect(calls.last.queryParameters['end'], '2026-11-03T23:59:59.999999');
      await tester.tap(find.byTooltip('Clear date filter'));
      await pumpRoute(tester);
      expect(calls.last.queryParameters.containsKey('start'), isFalse);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Operations switches between tables and cards on window resize', (
    tester,
  ) async {
    final calls = <Uri>[];
    await _open(tester, _service(calls), const Size(1440, 1000), 'dark');
    expect(find.byType(DataTable), findsOneWidget);
    final loads = calls.length;
    tester.view.physicalSize = const Size(375, 1000);
    await pumpRoute(tester);
    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(ListTile), findsNWidgets(3));
    tester.view.physicalSize = const Size(900, 1000);
    await pumpRoute(tester);
    expect(find.byType(DataTable), findsOneWidget);
    expect(calls.length, loads);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Operations Back remains mobile-only when the sidebar narrows the viewport',
    (tester) async {
      await _open(tester, _service([]), const Size(900, 1000), 'dark');
      final navigator = Navigator.of(
        tester.element(find.byKey(const Key('operationsTable'))),
      );
      navigator.pushNamed(AppRoutes.staffOperations);
      await pumpRoute(tester);
      expect(find.byTooltip('Back'), findsNothing);
      tester.view.physicalSize = const Size(375, 1000);
      await pumpRoute(tester);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
