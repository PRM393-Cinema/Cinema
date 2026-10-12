import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final status in ['SUCCESS', 'REFUND_PENDING']) {
    testWidgets(
      'Staff payment $status shows details without initiating refunds',
      (tester) async {
        tester.view.physicalSize = const Size(320, 924);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final requests = <http.Request>[];
        final service = StaffService(
          client: ApiClient(
            httpClient: MockClient((request) async {
              requests.add(request);
              final body = switch (request.url.path) {
                '/api/v1/payments/9' => {
                  'id': 9,
                  'paymentCode': 'PAY-20261011093107-869133',
                  'bookingId': 15,
                  'amount': 110000,
                  'status': status,
                  'method': 'PAYOS',
                  'transactionRef': '15',
                  'createdAt': '2026-10-11T09:31:07',
                },
                '/api/v1/payments/9/refund' || '/api/v1/payments/refunds/4' => {
                  'id': 4,
                  'refundCode': 'RF-4',
                  'paymentId': 9,
                  'bookingId': 15,
                  'amount': 110000,
                  'status': 'PENDING',
                  'createdAt': '2026-10-11T10:00:00',
                },
                _ => {
                  'items': [],
                  'pageNumber': 1,
                  'pageSize': 10,
                  'totalCount': 0,
                  'totalPages': 1,
                },
              };
              return http.Response(
                jsonEncode(body),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        );
        await tester.pumpWidget(
          buildAdminTestApp(
            authenticated: true,
            user: AuthUser.fromJson({
              ...customerUser.toJson(),
              'roles': ['ROLE_STAFF'],
            }),
            staffService: service,
            initialRoute: AppRoutes.staffRecord('payments', 9),
          ),
        );
        await pumpRoute(tester);
        expect(find.text('Payment details'), findsOneWidget);
        expect(find.text(formatVnd(110000)), findsOneWidget);
        expect(
          find.text(status == 'SUCCESS' ? 'Paid' : 'Refund pending'),
          findsOneWidget,
        );
        expect(find.text('Request refund'), findsNothing);
        if (status == 'REFUND_PENDING') {
          final scrollable = find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.text('View refund request'),
            160,
            scrollable: scrollable,
          );
          await tester.drag(find.byType(ListView), const Offset(0, -160));
          await pumpRoute(tester);
          await tester.tap(find.text('View refund request'));
          await pumpRoute(tester);
          expect(
            requests.map((request) => request.url.path),
            contains('/api/v1/payments/9/refund'),
          );
          expect(find.text('Refund details'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Record completed transfer'),
            160,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.text('Record completed transfer'), findsOneWidget);
        }
        expect(requests.every((request) => request.method == 'GET'), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
