import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/models/payment.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final status in ['PENDING', 'REJECTED', 'COMPLETED']) {
    testWidgets(
      'Staff refund $status fits small screen and has correct actions',
      (tester) async {
        tester.view.physicalSize = const Size(320, 924);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        String? rejectionReason;
        final service = StaffService(
          client: ApiClient(
            httpClient: MockClient((request) async {
              if (request.method == 'POST') {
                expect(request.url.path, '/api/v1/payments/refunds/4/reject');
                rejectionReason =
                    (jsonDecode(request.body) as Map)['reason'] as String;
              }
              return http.Response(
                jsonEncode({
                  'id': 4,
                  'refundCode': 'RF-20261011225250-216352',
                  'paymentId': 9,
                  'bookingId': 17,
                  'amount': 110000,
                  'status': rejectionReason == null ? status : 'REJECTED',
                  'createdAt': '2026-10-11T10:00:00',
                  'note':
                      rejectionReason ??
                      (status == 'REJECTED'
                          ? 'Bank details could not be verified'
                          : null),
                  'reason': 'Cancelled by customer in the app',
                }),
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
            initialRoute: AppRoutes.staffRecord('refunds', 4),
          ),
        );
        await pumpRoute(tester);
        expect(find.text('Recipient bank account'), findsOneWidget);
        final scrollable = find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('View booking'),
          200,
          scrollable: scrollable,
        );
        await tester.drag(find.byType(ListView), const Offset(0, -150));
        await pumpRoute(tester);
        expect(
          find.text('Reject refund'),
          status == 'PENDING' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Record completed transfer'),
          status == 'PENDING' ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        if (status == 'PENDING') {
          await tester.ensureVisible(find.text('Reject refund'));
          await tester.tap(find.text('Reject refund'));
          await pumpRoute(tester);
          await tester.tap(find.text('Continue'));
          await pumpRoute(tester);
          expect(find.text('Required.'), findsOneWidget);
          await tester.enterText(
            find.byType(TextFormField),
            'Bank details could not be verified',
          );
          await tester.tap(find.text('Continue'));
          await pumpRoute(tester);
          await tester.tap(find.text('Confirm'));
          await pumpRoute(tester);
          expect(rejectionReason, 'Bank details could not be verified');
          await tester.pump(const Duration(seconds: 3));
          await pumpRoute(tester);
          expect(find.text('Rejected'), findsOneWidget);
          expect(find.text('Reject refund'), findsNothing);
          expect(find.text('Record completed transfer'), findsNothing);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
  testWidgets('Customer sees rejected refund and reason', (tester) async {
    tester.view.physicalSize = const Size(320, 924);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final booking = bookingFixture(
      status: BookingStatus.confirmed,
      paymentId: 9,
    );
    final repo = FakeBookingRepository(bookings: [booking])
      ..refund = Refund(
        id: 4,
        refundCode: 'RF-4',
        paymentId: 9,
        amount: 180000,
        status: 'REJECTED',
        createdAt: DateTime.now(),
        note: 'Bank details could not be verified',
      );
    await tester.pumpWidget(
      buildTestApp(
        authenticated: true,
        bookingRepository: repo,
        initialRoute: AppRoutes.bookingDetail(booking.id),
      ),
    );
    await pumpRoute(tester);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -700),
    );
    await pumpRoute(tester);
    expect(find.text('Refund request rejected'), findsOneWidget);
    expect(find.text('Rejection reason'), findsOneWidget);
    expect(find.text('Bank details could not be verified'), findsOneWidget);
    expect(
      tester
          .widget<SelectableText>(find.byType(SelectableText).last)
          .style
          ?.fontSize,
      16,
    );
    expect(find.textContaining('in progress'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
