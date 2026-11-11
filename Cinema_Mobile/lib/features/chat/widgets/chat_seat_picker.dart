import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../data/models/booking_draft.dart';
import '../../../data/models/seat.dart';
import '../../seat/widgets/customer_seat_map.dart';
import '../../seat/widgets/seat_map_rows.dart';

class ChatSeatPicker extends StatefulWidget {
  const ChatSeatPicker({
    required this.show,
    required this.data,
    required this.tickets,
    required this.selected,
    super.key,
  });

  final BookingDraft show;
  final ShowtimeSeatsData data;
  final int tickets;
  final Set<int> selected;

  @override
  State<ChatSeatPicker> createState() => _ChatSeatPickerState();
}

class _ChatSeatPickerState extends State<ChatSeatPicker> {
  late final _selected = {...widget.selected};
  late final _rows = seatRowsOf(widget.data.seats);
  late final _suggestion = _suggestSeats();

  bool _free(Seat seat) =>
      widget.data.statusOf(seat) == SeatReservationStatus.available;

  bool _selectable(Seat seat) {
    if (!_free(seat)) return false;
    if (!seat.isSweetbox) return true;
    final partner = seat.sweetboxPartnerIn(widget.data.seats);
    return partner != null && _free(partner);
  }

  List<Seat> _suggestSeats() {
    final tickets = widget.tickets;
    final rows = _rows;
    final width = widestRowOf(rows);
    var best = const <Seat>[];
    var bestDistance = double.infinity;
    // Scan from the back so equally centred rows favour the one farther from the screen.
    for (var row = rows.length - 1; row >= 0; row--) {
      final seats = rows[row].$2;
      final rowDistance = (2 * row - rows.length + 1).abs() / rows.length;
      for (var i = 0; i + tickets <= seats.length; i++) {
        final seatDistance = (2 * i + tickets - seats.length).abs() / width;
        final distance = rowDistance + seatDistance;
        if (distance >= bestDistance) continue;
        final group = seats.sublist(i, i + tickets);
        if (group.last.number - group.first.number != tickets - 1 ||
            !group.every(
              (seat) =>
                  _free(seat) &&
                  seat.type == group.first.type &&
                  (!seat.isSweetbox || seat.sweetboxPartnerIn(group) != null),
            )) {
          continue;
        }
        best = group;
        bestDistance = distance;
      }
    }
    return best;
  }

  void _toggle(Seat seat, SeatReservationStatus status) {
    if (status != SeatReservationStatus.available || !_selectable(seat)) return;
    final partner = seat.sweetboxPartnerIn(widget.data.seats);
    final ids = {seat.id, if (partner != null) partner.id};
    setState(() {
      if (_selected.contains(seat.id)) {
        _selected.removeAll(ids);
      } else {
        _selected.addAll(ids);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = _suggestion;
    final chosen = widget.data.seats
        .where((seat) => _selected.contains(seat.id))
        .toList();
    final desktop = isDesktopLayout(context);
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final height = desktop ? 720.0 : math.min(720.0, 336 + 32.0 * _rows.length);
    final showtime = widget.show.showtime;
    const actionStyle = ButtonStyle(
      visualDensity: VisualDensity.standard,
      minimumSize: WidgetStatePropertyAll(Size(0, 52)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
    return Dialog(
      key: const Key('chatSeatPicker'),
      alignment: desktop ? Alignment.topCenter : Alignment.center,
      insetPadding: EdgeInsets.symmetric(
        horizontal: desktop ? 12 : 8,
        vertical: 16,
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: desktop
            ? 900
            : landscape
            ? 440
            : 560,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chọn ghế',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${widget.show.movie.title}${desktop ? ' · ' : '\n'}${formatDateTime(showtime.startTime)} · ${showtime.roomLabel}',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Đóng sơ đồ ghế',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.data.seats.isEmpty
                  ? const Center(child: Text('Phòng chưa có sơ đồ ghế.'))
                  : CustomerSeatMap(
                      data: widget.data,
                      showtime: showtime,
                      selectedSeatIds: _selected,
                      canSelect: _selectable,
                      onSeatTap: _toggle,
                      compact: !desktop,
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: IntrinsicHeight(
                child: Row(
                  spacing: 12,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (suggestion.isNotEmpty)
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('chatUseSuggestedSeats'),
                          style: actionStyle,
                          onPressed: () => setState(() {
                            _selected
                              ..clear()
                              ..addAll(suggestion.map((seat) => seat.id));
                          }),
                          child: Text(
                            'Gợi ý ${suggestion.map((seat) => seat.label).join(', ')}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    Expanded(
                      child: FilledButton(
                        key: const Key('applyChatSeats'),
                        style: actionStyle,
                        onPressed: chosen.isNotEmpty
                            ? () => Navigator.pop(context, chosen)
                            : null,
                        child: const Text('Xong'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
