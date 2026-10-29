import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/core/widgets/app_button.dart';
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
  for (final (width, scale) in [(320.0, 1.0), (412.0, 1.5)]) {
    testWidgets('Staff booking details fit $width with text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 924);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const email = 'customer.with.a.long.email.address@example.com';
      const bookingCode = 'BK-20261011093105-800609';
      final service = StaffService(
        client: ApiClient(
          httpClient: MockClient((request) async {
            final Object body = request.url.path == '/api/v1/bookings/15'
                ? {
                    'id': 15,
                    'bookingCode': bookingCode,
                    'userId': 13,
                    'customerEmail': email,
                    'showtimeId': 7,
                    'status': 'CONFIRMED',
                    'totalAmount': 110000,
                    'movieTitle': 'Chuyến Tàu Sinh Tử',
                    'showTime': '2030-10-11T19:45:00',
                    'createdAt': '2026-10-11T09:31:05',
                    'seats': [
                      {
                        'id': 1,
                        'seatId': 5,
                        'seatLabel': 'C5',
                        'price': 110000,
                      },
                    ],
                  }
                : {
                    'items': request.url.path == '/api/v1/payments/booking/15'
                        ? [
                            {
                              'id': 9,
                              'paymentCode': 'PAY-9',
                              'bookingId': 15,
                              'amount': 110000,
                              'status': 'SUCCESS',
                              'createdAt': '2026-10-11T09:31:07',
                            },
                          ]
                        : [],
                    'pageNumber': 1,
                    'pageSize': 10,
                    'totalCount': 1,
                    'totalPages': 1,
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
          initialRoute: AppRoutes.staffRecord('bookings', 15),
        ),
      );
      await pumpRoute(tester);
      expect(find.text('Booking details'), findsOneWidget);
      expect(find.text('Chuyến Tàu Sinh Tử'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      final scrollable = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      for (final text in [
        'Booking: $bookingCode',
        'Seats (1)',
        'C5',
        'Customer #13',
        email,
        'Total amount',
        formatVnd(110000),
      ]) {
        await tester.scrollUntilVisible(
          find.text(text),
          140,
          scrollable: scrollable,
        );
        expect(find.text(text), findsOneWidget);
      }
      for (final (label, variant) in [
        ('Show ticket', AppButtonVariant.secondary),
        ('Send customer notification', AppButtonVariant.secondary),
        ('View payment', AppButtonVariant.secondary),
        ('Cancel booking', AppButtonVariant.danger),
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          140,
          scrollable: scrollable,
        );
        final button = tester.widget<AppButton>(
          find.byWidgetPredicate(
            (widget) => widget is AppButton && widget.label == label,
          ),
        );
        expect(button.variant, variant);
        expect(button.onPressed, isNotNull);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
