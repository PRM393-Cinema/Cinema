import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/models/seat.dart';
import '../../../data/services/staff_service.dart';
import '../../seat/widgets/seat_map_rows.dart';
import '../../seat/widgets/seat_type_style.dart';
import 'staff_feedback.dart';

// Rows are lettered A to Z; the admin room form allows 30 seats per row.
const maxSeatRows = 26;
const maxSeatsPerRow = 30;

// The seat map of a room for staff: seats coloured by type, in rows facing
// the screen like the customer seat map. Tapping a seat offers its types;
// [highlighted] seats (just added) glow. With a [paintType], tapping or
// dragging across seats, or tapping a row letter, gives them that type
// instead ([onPaint] saves it).
class RoomSeatMap extends StatefulWidget {
  const RoomSeatMap({
    required this.seats,
    this.highlighted = const {},
    this.onTypeSelected,
    this.paintType,
    this.onPaint,
    super.key,
  });

  final List<Seat> seats;
  final Set<int> highlighted;

  // Null while a change is being saved: the seats cannot be tapped.
  final void Function(Seat seat, String type)? onTypeSelected;

  final String? paintType;

  // Null while a change is being saved: nothing can be painted.
  final void Function(List<Seat> seats)? onPaint;

  @override
  State<RoomSeatMap> createState() => _RoomSeatMapState();
}

class _RoomSeatMapState extends State<RoomSeatMap> {
  final _mapKey = GlobalKey();

  // Seats under the pointer while painting, shown in the new type.
  final _painting = <int>{};
  Offset? _downAt;

  bool get _paintMode => widget.paintType != null;

  Seat? _seatAt(Offset global) {
    final box = _mapKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return null;
    final result = BoxHitTestResult();
    box.hitTest(result, position: box.globalToLocal(global));
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData && target.metaData is Seat) {
        return target.metaData as Seat;
      }
    }
    return null;
  }

  void _add(Offset? global) {
    final seat = global == null ? null : _seatAt(global);
    if (seat != null && _painting.add(seat.id)) setState(() {});
  }

  void _finish() {
    final seats = [
      for (final seat in widget.seats)
        if (_painting.contains(seat.id)) seat,
    ];
    setState(_painting.clear);
    if (seats.isNotEmpty) widget.onPaint?.call(seats);
  }

  @override
  Widget build(BuildContext context) {
    final seats = widget.seats;
    final rows = seatRowsOf(seats);
    final widest = widestRowOf(rows);
    final onPaint = widget.onPaint;
    final paintType = widget.paintType;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = SeatMapLayout.fit(
          maxWidth: constraints.maxWidth,
          seatsPerRow: widest,
        );
        Widget map = Padding(
          key: _mapKey,
          padding: const EdgeInsets.all(SeatMapLayout.padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SeatScreenIndicator(width: layout.seatsWidth(widest)),
              const SizedBox(height: AppSpacing.xl),
              SeatMapRows(
                rows: rows,
                layout: layout,
                onRowTap: _paintMode ? onPaint : null,
                seatBuilder: (seat, size) => _RoomSeat(
                  key: ValueKey('roomSeat-${seat.label}'),
                  seat: seat,
                  pair: seats
                      .where(
                        (s) => s.row == seat.row && s.number == seat.pairNumber,
                      )
                      .firstOrNull,
                  size: size,
                  highlighted: widget.highlighted.contains(seat.id),
                  onTypeSelected: widget.onTypeSelected,
                  paintMode: _paintMode,
                  preview: _painting.contains(seat.id) ? paintType : null,
                ),
              ),
            ],
          ),
        );
        if (_paintMode && onPaint != null) {
          // A tap paints one seat; a drag paints every seat it crosses.
          map = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              _add(details.globalPosition);
              _finish();
            },
            onPanDown: (details) => _downAt = details.globalPosition,
            onPanStart: (details) {
              _add(_downAt);
              _add(details.globalPosition);
            },
            onPanUpdate: (details) => _add(details.globalPosition),
            onPanEnd: (_) => _finish(),
            onPanCancel: () => setState(_painting.clear),
            child: map,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${rows.length} rows • ${seats.length} seats',
              key: const Key('roomSeatSummary'),
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            // Very wide rooms scroll sideways instead of shrinking seats
            // below a tappable size (not while painting: a drag paints).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: _paintMode ? const NeverScrollableScrollPhysics() : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Center(child: map),
              ),
            ),
            _Legend(seats: seats, showNew: widget.highlighted.isNotEmpty),
          ],
        );
      },
    );
  }
}

class _RoomSeat extends StatelessWidget {
  const _RoomSeat({
    required this.seat,
    required this.pair,
    required this.size,
    required this.highlighted,
    required this.onTypeSelected,
    this.paintMode = false,
    this.preview,
    super.key,
  });

  final Seat seat;

  // The seat a sweetbox would pair with (1 with 2, 4 with 3), if the row has
  // it. A sweetbox changes type together with its pair.
  final Seat? pair;
  final double size;
  final bool highlighted;
  final void Function(Seat seat, String type)? onTypeSelected;

  // Painting: the map handles taps and drags, so the seat has no menu.
  final bool paintMode;

  // The type the seat is being painted to.
  final String? preview;

  @override
  Widget build(BuildContext context) {
    final (fill, border, text) = seatTypeColors(preview ?? seat.type);
    final radius = BorderRadius.circular(math.min(AppRadius.sm, size / 5));
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(
          color: highlighted ? AppColors.primary : border,
          width: highlighted ? 2 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Text(
        '${seat.number}',
        style: AppTextStyles.caption.copyWith(
          color: text,
          fontSize: size < 36 ? 10 : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (paintMode) {
      return MetaData(
        metaData: seat,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: '${seat.label} • ${seatTypeLabel(seat.type)}',
          child: tile,
        ),
      );
    }

    final select = onTypeSelected;
    final pair = this.pair;
    final paired = seat.isSweetbox && (pair?.isSweetbox ?? false);
    String itemLabel(String type) {
      if (type == 'SWEETBOX') {
        return pair == null
            ? 'Sweetbox (no ${seat.row}${seat.pairNumber} to pair with)'
            : 'Sweetbox (with ${pair.label})';
      }
      return paired
          ? '${seatTypeLabel(type)} (with ${pair!.label})'
          : seatTypeLabel(type);
    }

    return PopupMenuButton<String>(
      enabled: select != null,
      tooltip: '${seat.label} • ${seatTypeLabel(seat.type)}',
      onSelected: (type) => select?.call(seat, type),
      itemBuilder: (_) => [
        for (final type in seatTypes)
          CheckedPopupMenuItem(
            value: type,
            checked: seat.type.toUpperCase() == type,
            enabled: type != 'SWEETBOX' || pair != null,
            child: Text(itemLabel(type)),
          ),
      ],
      child: tile,
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.seats, required this.showNew});

  final List<Seat> seats;
  final bool showNew;

  @override
  Widget build(BuildContext context) {
    int count(String type) =>
        seats.where((seat) => seat.type.toUpperCase() == type).length;
    final standard =
        seats.length - seatTypes.skip(1).map(count).fold(0, (a, b) => a + b);

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      alignment: WrapAlignment.center,
      children: [
        for (final type in seatTypes)
          _LegendEntry(
            type: type,
            label:
                '${seatTypeLabel(type)} '
                '(${type == 'NORMAL' ? standard : count(type)})',
          ),
        if (showNew) const _LegendEntry(label: 'Just added', highlighted: true),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.label,
    this.type = 'NORMAL',
    this.highlighted = false,
  });

  final String label;
  final String type;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final (fill, border, _) = seatTypeColors(type);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: highlighted ? AppColors.primary : border,
              width: highlighted ? 2 : 1,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

// What a new seat count does to a room, the way the API applies it: new seats
// fill the last row up to [seatsPerRow], then the next rows (A to Z); fewer
// seats remove the last ones, and a sweetbox seat whose pair is removed
// becomes a standard seat ([unpaired]). Labels are in A to Z order.
class SeatCountPlan {
  const SeatCountPlan({
    this.added = const [],
    this.removed = const [],
    this.unpaired = const [],
    this.error,
  });

  final List<String> added;
  final List<String> removed;
  final List<String> unpaired;
  final String? error;
}

SeatCountPlan planSeatCount(List<Seat> seats, int total, int seatsPerRow) {
  final rows = seatRowsOf(seats, sweetboxLast: false);
  final ordered = [for (final (_, row) in rows) ...row];
  if (total < ordered.length) {
    final kept = ordered.take(total).toList();
    final removed = ordered.skip(total).toList();
    return SeatCountPlan(
      removed: [for (final seat in removed) seat.label],
      unpaired: [
        for (final seat in kept)
          if (seat.sweetboxPartnerIn(removed) != null) seat.label,
      ],
    );
  }

  final lastRow = ordered.isEmpty ? <Seat>[] : rows.last.$2;
  final added = <String>[];
  var row = lastRow.isEmpty ? null : lastRow.last.row;
  var inRow = lastRow.length;
  var next = lastRow.isEmpty ? 1 : lastRow.last.number + 1;
  while (ordered.length + added.length < total) {
    if (row == null || inRow >= seatsPerRow) {
      row = _nextRow(row);
      if (row == null) {
        return const SeatCountPlan(
          error: 'Not enough rows: a room has rows A to Z. Use more seats per row.',
        );
      }
      inRow = 0;
      next = 1;
    }
    added.add('$row${next++}');
    inRow++;
  }
  return SeatCountPlan(added: added);
}

String? _nextRow(String? row) {
  if (row == null) return 'A';
  return row.length == 1 && row.compareTo('A') >= 0 && row.compareTo('Z') < 0
      ? String.fromCharCode(row.codeUnitAt(0) + 1)
      : null;
}

// "C4–C10, D1–D3": seats in map order, consecutive seats of a row as a range.
String describeSeats(List<String> labels) {
  final ranges = <(String, int, int)>[];
  for (final label in labels) {
    final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(label);
    if (match == null) continue;
    final (row, number) = (match.group(1)!, int.parse(match.group(2)!));
    final last = ranges.lastOrNull;
    if (last != null && last.$1 == row && last.$3 + 1 == number) {
      ranges.last = (row, last.$2, number);
    } else {
      ranges.add((row, number, number));
    }
  }
  return ranges
      .map(
        (r) =>
            r.$2 == r.$3 ? '${r.$1}${r.$2}' : '${r.$1}${r.$2}–${r.$1}${r.$3}',
      )
      .join(', ');
}

// Admin: changes how many seats a room has and returns its new seat map.
class SeatCountDialog extends StatefulWidget {
  const SeatCountDialog({
    required this.service,
    required this.roomId,
    required this.seats,
    super.key,
  });

  final StaffService service;
  final int roomId;
  final List<Seat> seats;

  @override
  State<SeatCountDialog> createState() => _SeatCountDialogState();
}

class _SeatCountDialogState extends State<SeatCountDialog> {
  late final _total = TextEditingController(text: '${widget.seats.length}');
  late final _perRow = TextEditingController(
    text: '${math.max(widestRowOf(seatRowsOf(widget.seats)), 1)}',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _total.dispose();
    _perRow.dispose();
    super.dispose();
  }

  int? _value(TextEditingController controller, int max) {
    final value = int.tryParse(controller.text.trim());
    return value == null || value < 1 || value > max ? null : value;
  }

  int? get _totalValue => _value(_total, maxSeatRows * maxSeatsPerRow);
  int? get _perRowValue => _value(_perRow, maxSeatsPerRow);

  SeatCountPlan? get _plan {
    final total = _totalValue;
    final perRow = _perRowValue;
    return total == null || perRow == null
        ? null
        : planSeatCount(widget.seats, total, perRow);
  }

  Future<void> _save() async {
    final total = _totalValue;
    final perRow = _perRowValue;
    if (total == null || perRow == null || _plan?.error != null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final seats = await widget.service.setRoomSeatCount(
        widget.roomId,
        total,
        seatsPerRow: perRow,
      );
      if (mounted) Navigator.pop(context, seats);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = staffError(error);
      });
    }
  }

  void _step(int by) {
    final total = (_totalValue ?? widget.seats.length) + by;
    _total.text = '${total.clamp(1, maxSeatRows * maxSeatsPerRow)}';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final current = widget.seats.length;
    final total = _totalValue;
    final preview = switch (plan) {
      null when total == null =>
        'Enter 1 to ${maxSeatRows * maxSeatsPerRow} seats.',
      null => 'Enter 1 to $maxSeatsPerRow seats per row.',
      SeatCountPlan(:final error?) => error,
      SeatCountPlan(:final added) when added.isNotEmpty =>
        '$current to ${current + added.length} seats (+${added.length}): '
            'adds ${describeSeats(added)}.',
      SeatCountPlan(:final removed, :final unpaired) when removed.isNotEmpty =>
        '$current to ${current - removed.length} seats (-${removed.length}): '
            'removes ${describeSeats(removed)}.'
            '${unpaired.isEmpty ? '' : ' ${describeSeats(unpaired)} becomes '
                      'a standard seat: its sweetbox pair is removed.'}',
      _ => 'No change: the room has $current seats.',
    };
    final canSave =
        !_saving &&
        plan != null &&
        plan.error == null &&
        (plan.added.isNotEmpty || plan.removed.isNotEmpty);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: CinemaPanel(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Change seat count', style: AppTextStyles.heading2),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'New seats fill the last row, then start new rows. Fewer '
                  'seats remove the last ones. Existing seats keep their '
                  'labels and types.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: '10 fewer seats',
                      onPressed: _saving ? null : () => _step(-10),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Expanded(
                      child: AppTextField(
                        key: const Key('seatCountField'),
                        label: 'Total seats',
                        controller: _total,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      tooltip: '10 more seats',
                      onPressed: _saving ? null : () => _step(10),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  key: const Key('seatsPerRowField'),
                  label: 'Seats per row (new rows)',
                  controller: _perRow,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  preview,
                  key: const Key('seatCountPreview'),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: plan?.error != null
                        ? AppColors.error
                        : AppColors.textPrimary,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    key: const Key('seatCountError'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.secondary(
                        label: 'Cancel',
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        key: const Key('saveSeatCountButton'),
                        label: 'Save',
                        useGradient: true,
                        isLoading: _saving,
                        onPressed: canSave ? _save : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
