import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  for (final (width, scale) in [(320.0, 1.0), (412.0, 1.5)]) {
    testWidgets(
      'Operations payments are readable at $width with text scale $scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 924);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final paths = <String>[];
        final payments = [
          for (final (id, status) in [
            (1, 'SUCCESS'),
            (2, 'FAILED'),
            (3, 'PENDING'),
          ])
            {
              'id': id,
              'paymentCode': 'PAY-20261011093107-869133-$id',
              'bookingId': 15 + id,
              'amount': 110000,
              'status': status,
              'createdAt': '2026-10-11T09:31:07',
            },
        ];
        final service = StaffService(
          client: ApiClient(
            httpClient: MockClient((request) async {
              paths.add(request.url.path);
              return http.Response(
                jsonEncode({
                  'items': request.url.path == '/api/v1/payments'
                      ? payments
                      : [],
                  'pageNumber': 1,
                  'pageSize': 10,
                  'totalCount': request.url.path == '/api/v1/payments' ? 3 : 0,
                  'totalPages': 1,
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        );
        await tester.pumpWidget(
          buildTestApp(
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
        final tabs = find.byType(SingleChildScrollView);
        final bookings = tester.getRect(
          find.widgetWithText(ChoiceChip, 'Bookings'),
        );
        final refunds = tester.getRect(
          find.widgetWithText(ChoiceChip, 'Refunds'),
        );
        expect(bookings.top, refunds.top);
        expect(refunds.right, greaterThan(width));
        await tester.drag(tabs, const Offset(-600, 0));
        await pumpRoute(tester);
        expect(
          find.widgetWithText(ChoiceChip, 'Refunds').hitTestable(),
          findsOneWidget,
        );
        await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Payments'));
        await pumpRoute(tester);
        await tester.tap(find.widgetWithText(ChoiceChip, 'Payments'));
        await pumpRoute(tester);
        expect(paths, contains('/api/v1/bookings'));
        expect(paths.last, '/api/v1/payments');
        expect(find.text('3 payments'), findsOneWidget);
        expect(find.text('Paid'), findsOneWidget);
        expect(find.text(formatVnd(110000)), findsWidgets);
        expect(find.text('Booking #16'), findsOneWidget);
        expect(
          find.text('Payment: PAY-20261011093107-869133-1'),
          findsOneWidget,
        );
        final scrollable = find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first;
        for (final label in ['Failed', 'Awaiting payment']) {
          await tester.scrollUntilVisible(
            find.text(label),
            160,
            scrollable: scrollable,
          );
          await tester.pumpAndSettle();
          expect(find.text(label), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
