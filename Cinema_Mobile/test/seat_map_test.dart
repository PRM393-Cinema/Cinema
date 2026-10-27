import 'package:cinema_fe/data/models/seat.dart';
import 'package:cinema_fe/features/seat/widgets/seat_map_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Seat _seat(String row, int number, [String type = 'NORMAL']) => Seat(
  id: row.codeUnitAt(0) * 100 + number,
  roomId: 1,
  row: row,
  number: number,
  type: type,
);

void main() {
  group('Sweetbox pairs', () {
    final row = [for (var n = 1; n <= 4; n++) _seat('C', n, 'SWEETBOX')];

    test('an odd seat pairs with the seat on its right, an even one left', () {
      expect(row[0].sweetboxPartnerIn(row)?.label, 'C2');
      expect(row[1].sweetboxPartnerIn(row)?.label, 'C1');
      expect(row[2].sweetboxPartnerIn(row)?.label, 'C4');
      expect(row[3].sweetboxPartnerIn(row)?.label, 'C3');
    });

    test('only two sweetbox seats make a pair', () {
      final mixed = [_seat('A', 1, 'SWEETBOX'), _seat('A', 2, 'VIP')];
      expect(mixed[0].sweetboxPartnerIn(mixed), isNull);
      expect(mixed[1].sweetboxPartnerIn(mixed), isNull);
    });
  });

  test('Sweetbox rows go to the back of the seat map', () {
    final seats = [
      _seat('A', 1),
      _seat('B', 1, 'SWEETBOX'),
      _seat('B', 2, 'SWEETBOX'),
      _seat('C', 1, 'VIP'),
    ];

    expect([for (final (row, _) in seatRowsOf(seats)) row], ['A', 'C', 'B']);
    expect(
      [for (final (row, _) in seatRowsOf(seats, sweetboxLast: false)) row],
      ['A', 'B', 'C'],
    );
  });

  testWidgets('A sweetbox row keeps the columns of the rows in front', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SeatMapRows(
            rows: [
              ('A', [for (var n = 1; n <= 10; n++) _seat('A', n)]),
              ('C', [for (var n = 1; n <= 10; n++) _seat('C', n, 'SWEETBOX')]),
            ],
            layout: const SeatMapLayout(seatSize: 30, gap: 12),
            seatBuilder: (seat, size) =>
                SizedBox.square(key: Key(seat.label), dimension: size),
          ),
        ),
      ),
    );

    double left(String label) => tester.getTopLeft(find.byKey(Key(label))).dx;
    for (var n = 1; n <= 10; n++) {
      expect(left('C$n'), left('A$n'), reason: 'C$n under A$n');
    }

    // No aisle gaps: seats are evenly spaced, so sweetbox 5-6 stays together.
    final step = left('A2') - left('A1');
    for (var n = 2; n <= 10; n++) {
      expect(left('A$n') - left('A${n - 1}'), step, reason: 'A${n - 1}-A$n');
    }

    // Each sweetbox (1-2, 3-4, ...) shares one band.
    Finder band(String label) => find.ancestor(
      of: find.byKey(Key(label)),
      matching: find.byType(DecoratedBox),
    );
    for (final (a, b, next) in [('C1', 'C2', 'C3'), ('C5', 'C6', 'C7')]) {
      expect(
        find.descendant(of: band(a).first, matching: find.byKey(Key(b))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: band(a).first, matching: find.byKey(Key(next))),
        findsNothing,
      );
    }
    expect(band('A1'), findsNothing);
  });
}
