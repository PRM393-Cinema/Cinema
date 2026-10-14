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

  testWidgets('A sweetbox sits together and no aisle splits it', (
    tester,
  ) async {
    final row = [for (var n = 1; n <= 10; n++) _seat('C', n, 'SWEETBOX')];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SeatMapRows(
            rows: [('C', row)],
            layout: const SeatMapLayout(seatSize: 30, gap: 12),
            seatBuilder: (seat, size) =>
                SizedBox.square(key: Key(seat.label), dimension: size),
          ),
        ),
      ),
    );

    double gap(String left, String right) =>
        tester.getTopLeft(find.byKey(Key(right))).dx -
        tester.getTopRight(find.byKey(Key(left))).dx;

    expect(gap('C1', 'C2'), SeatMapRows.pairGap);
    expect(gap('C5', 'C6'), SeatMapRows.pairGap);
    // The middle aisle moves from C5|C6 to C4|C5.
    expect(gap('C4', 'C5'), 12 + SeatMapLayout.aisleWidth);
    expect(gap('C6', 'C7'), 12);
  });
}
