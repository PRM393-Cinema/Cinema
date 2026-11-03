import 'dart:convert';

import 'package:cinema_fe/app/theme/app_theme.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/data/models/room.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:cinema_fe/features/staff/widgets/today_showtimes_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fixtures.dart';

void main() {
  for (final light in [true, false]) {
    for (final size in [
      const Size(1440, 900),
      const Size(375, 844),
      const Size(844, 390),
    ]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('Showtime pages light=$light size=$size scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var count = 25;
          var fail = false;
          var requests = 0;
          final now = DateTime.now();
          final service = StaffService(
            client: ApiClient(
              httpClient: MockClient((request) async {
                requests++;
                if (fail) return http.Response('{}', 500);
                final Object data = request.url.path.endsWith('/stats')
                    ? [
                        {
                          'showtimeId': 25,
                          'soldSeats': 2,
                          'heldSeats': 1,
                          'checkedInSeats': 1,
                        },
                      ]
                    : {
                        'items': [
                          for (var i = 1; i <= count; i++)
                            {
                              'id': i,
                              'movieId': 1,
                              'roomId': i.isOdd ? 1 : 2,
                              'startTime': now
                                  .add(Duration(minutes: i * 10))
                                  .toIso8601String(),
                              'endTime': now
                                  .add(Duration(minutes: i * 10 + 100))
                                  .toIso8601String(),
                              'price': 90000,
                              'status': 'OPEN',
                              'format': '2D',
                            },
                        ],
                        'totalPages': 1,
                        'totalCount': count,
                        'pageNumber': 1,
                      };
                return http.Response(
                  jsonEncode(data),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }),
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: TodayShowtimesDialog(
                  service: service,
                  movies: {1: inception},
                  rooms: const {
                    1: Room(id: 1, name: 'Room A', totalSeats: 54),
                    2: Room(id: 2, name: 'Room B', totalSeats: 38),
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Page 1 of 3'), findsOneWidget);
          expect(
            find.byType(DataTable),
            size.width >= 900 ? findsOneWidget : findsNothing,
          );
          expect(
            tester
                .widget<IconButton>(
                  find.byKey(const Key('todayShowtimesPrevious')),
                )
                .onPressed,
            isNull,
          );
          final footer = tester.getRect(
            find.byKey(const Key('todayShowtimesPagination')),
          );
          expect(footer.bottom, lessThanOrEqualTo(size.height));
          final readCount = requests;
          await tester.tap(find.byKey(const Key('todayShowtimesNext')));
          await tester.pumpAndSettle();
          expect(find.text('Page 2 of 3'), findsOneWidget);
          expect(find.byKey(const ValueKey('todayShowtime-1')), findsNothing);
          expect(
            find.byKey(const ValueKey('todayShowtime-11')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('todayShowtimesNext')));
          await tester.pumpAndSettle();
          expect(find.text('21–25 of 25'), findsOneWidget);
          expect(
            tester
                .widget<IconButton>(find.byKey(const Key('todayShowtimesNext')))
                .onPressed,
            isNull,
          );
          expect(requests, readCount);
          await tester.ensureVisible(
            find.byKey(const Key('todayShowtimesWithTickets')),
          );
          await tester.tap(find.byKey(const Key('todayShowtimesWithTickets')));
          await tester.pumpAndSettle();
          expect(find.text('Page 1 of 1'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('todayShowtime-25')),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Clear filters'));
          await tester.tap(find.text('Clear filters'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('todayShowtimesPageSize')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('5').last);
          await tester.pumpAndSettle();
          expect(find.text('Page 1 of 5'), findsOneWidget);
          await tester.ensureVisible(
            find.byKey(const Key('todayShowtimesRoom')),
          );
          await tester.tap(find.byKey(const Key('todayShowtimesRoom')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Room B').last);
          await tester.pumpAndSettle();
          expect(find.text('12 of 25 showtimes'), findsOneWidget);
          expect(find.text('Page 1 of 3'), findsOneWidget);
          expect(find.byKey(const ValueKey('todayShowtime-1')), findsNothing);
          await tester.ensureVisible(
            find.byKey(const Key('todayShowtimesSearch')),
          );
          await tester.enterText(
            find.descendant(
              of: find.byKey(const Key('todayShowtimesSearch')),
              matching: find.byType(EditableText),
            ),
            'No such movie',
          );
          await tester.pumpAndSettle();
          expect(find.text('0–0 of 0'), findsOneWidget);
          expect(
            find.text('No showtimes match these filters.'),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Clear filters'));
          await tester.tap(find.text('Clear filters'));
          await tester.pumpAndSettle();
          count = 0;
          await tester.tap(find.byTooltip('Refresh'));
          await tester.pumpAndSettle();
          expect(find.text('There are no showtimes today.'), findsOneWidget);
          fail = true;
          await tester.tap(find.byTooltip('Refresh'));
          await tester.pumpAndSettle();
          expect(find.textContaining('could not be loaded'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
