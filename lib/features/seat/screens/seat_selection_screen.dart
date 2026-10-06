import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/booking_draft.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/seat.dart';
import '../../../data/models/showtime.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../widgets/seat_item.dart';
import '../widgets/seat_legend.dart';

class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({required this.catalogRepository, super.key});

  final CatalogRepository catalogRepository;

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  final Set<int> _selectedSeatIds = {};
  SeatSelectionArgs? _args;
  ShowtimeSeatsData? _data;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (_args == null && args is SeatSelectionArgs) {
      _args = args;
      _loadSeatMap();
    }
  }

  Future<void> _loadSeatMap() async {
    final args = _args;
    if (args == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await widget.catalogRepository.getSeatMap(args.showtime);
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
        // Drop selections that someone else took in the meantime.
        _selectedSeatIds.removeWhere((id) => data.reservations.containsKey(id));
      });
    } on ApiException catch (error) {
      _showError(error.message);
    } on FormatException {
      _showError('The server returned an invalid response.');
    } on Object {
      _showError('Something went wrong. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  void _toggleSeat(Seat seat, SeatReservationStatus status) {
    if (status == SeatReservationStatus.held ||
        status == SeatReservationStatus.booked) {
      return; // Cannot select
    }
    setState(() {
      if (_selectedSeatIds.contains(seat.id)) {
        _selectedSeatIds.remove(seat.id);
      } else {
        _selectedSeatIds.add(seat.id);
      }
    });
  }

  // Selected seats in row then number order (A2 before A10).
  List<Seat> _selectedSeats(ShowtimeSeatsData? data) {
    if (data == null) return const [];
    return data.seats
        .where((seat) => _selectedSeatIds.contains(seat.id))
        .toList()
      ..sort((a, b) {
        final byRow = a.row.compareTo(b.row);
        return byRow != 0 ? byRow : a.number.compareTo(b.number);
      });
  }

  Future<void> _continue(SeatSelectionArgs args, ShowtimeSeatsData data) async {
    final seats = _selectedSeats(data);

    final seatsTaken = await Navigator.pushNamed(
      context,
      AppRoutes.bookingSummary,
      arguments: BookingDraft(
        movie: args.movie,
        showtime: args.showtime,
        seats: seats,
      ),
    );

    // The summary returns true when some seats were taken before the booking
    // was created: reload the map so the customer can pick again.
    if (seatsTaken == true && mounted) {
      await _loadSeatMap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;

    if (args == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seat Selection')),
        body: const ErrorState(
          title: 'Showtime not found',
          message: 'Please return and select a showtime again.',
        ),
      );
    }

    final showtime = args.showtime;
    final data = _data;
    final totalPrice = _selectedSeatIds.length * showtime.price;
    final selectedLabels = _selectedSeats(data)
        .map((seat) => seat.label)
        .join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Select Seats')),
      body: SafeArea(
        child: Column(
          children: [
            _ShowtimeSummary(movie: args.movie, showtime: showtime),
            const Divider(height: 1, color: AppColors.border),
            Expanded(child: _buildSeatMap(data)),
            const Divider(height: 1, color: AppColors.border),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              color: AppColors.surface,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // A large total shrinks instead of pushing the
                        // button off narrow screens.
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${_selectedSeatIds.length} seat(s)',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                  if (selectedLabels.isNotEmpty)
                                    Flexible(
                                      child: Text(
                                        ' • $selectedLabels',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  formatVnd(totalPrice),
                                  style: AppTextStyles.heading2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        AppButton(
                          label: 'Continue',
                          onPressed: data != null && _selectedSeatIds.isNotEmpty
                              ? () => _continue(args, data)
                              : null,
                        ),
                      ],
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

  Widget _buildSeatMap(ShowtimeSeatsData? data) {
    if (_isLoading) {
      return const LoadingState(message: 'Loading seats...');
    }

    if (_errorMessage != null || data == null) {
      return ErrorState(
        title: 'Unable to load seats',
        message: _errorMessage ?? 'Please try again.',
        onRetry: _loadSeatMap,
      );
    }

    if (data.seats.isEmpty) {
      return const EmptyState(
        icon: Icons.event_seat_outlined,
        title: 'No seats configured',
        message: 'This room has no seat map yet.',
      );
    }

    return _SeatMap(
      data: data,
      selectedSeatIds: _selectedSeatIds,
      onSeatTap: _toggleSeat,
    );
  }
}

// What is being booked: shown above the seat map.
class _ShowtimeSummary extends StatelessWidget {
  const _ShowtimeSummary({required this.movie, required this.showtime});

  final Movie movie;
  final Showtime showtime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          AppNetworkImage(
            imageUrl: movie.posterUrl,
            width: 48,
            height: 72,
            borderRadius: AppRadius.borderRadiusSm,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  style: AppTextStyles.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${formatDayHeading(showtime.startTime)} • '
                  '${formatTime(showtime.startTime)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${showtime.roomLabel} • ${formatVnd(showtime.price)} / seat',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatMap extends StatelessWidget {
  const _SeatMap({
    required this.data,
    required this.selectedSeatIds,
    required this.onSeatTap,
  });

  final ShowtimeSeatsData data;
  final Set<int> selectedSeatIds;
  final void Function(Seat seat, SeatReservationStatus status) onSeatTap;

  SeatItemState _itemStateOf(Seat seat, SeatReservationStatus status) {
    if (selectedSeatIds.contains(seat.id)) {
      return SeatItemState.selected;
    }
    return switch (status) {
      SeatReservationStatus.held => SeatItemState.held,
      SeatReservationStatus.booked => SeatItemState.booked,
      SeatReservationStatus.available => SeatItemState.available,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Group seats by row
    final Map<String, List<Seat>> rows = {};
    for (final seat in data.seats) {
      rows.putIfAbsent(seat.row, () => []).add(seat);
    }

    // Sort rows alphabetically (A, B, C...)
    final sortedRowKeys = rows.keys.toList()..sort();

    // Sort seats in each row by seat number
    for (final row in sortedRowKeys) {
      rows[row]!.sort((a, b) => a.number.compareTo(b.number));
    }

    final seatsPerRow = rows.values.fold<int>(
      0,
      (widest, row) => math.max(widest, row.length),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _SeatMapLayout.fit(
          maxWidth: constraints.maxWidth,
          seatsPerRow: seatsPerRow,
        );
        final fitsScreen = layout.mapWidth(seatsPerRow) <= constraints.maxWidth;

        return InteractiveViewer(
          // Pinch to zoom in on small seats; very wide rooms can also be
          // zoomed out and panned.
          minScale: fitsScreen ? 1 : 0.5,
          maxScale: 3,
          constrained: false,
          // Small rooms sit in the middle of the free space instead of
          // leaving a gap below the seats.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              minHeight: constraints.maxHeight,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(_SeatMapLayout.padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ScreenIndicator(width: layout.seatsWidth(seatsPerRow)),
                    const SizedBox(height: AppSpacing.xl),
                    ...sortedRowKeys.map((rowKey) {
                      final rowSeats = rows[rowKey]!;
                      return Padding(
                        padding: EdgeInsets.only(bottom: layout.gap),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _RowLabel(label: rowKey),
                            const SizedBox(width: _SeatMapLayout.labelGap),
                            for (final (index, seat) in rowSeats.indexed) ...[
                              if (index > 0) SizedBox(width: layout.gap),
                              SeatItem(
                                label: seat.number.toString(),
                                state: _itemStateOf(seat, data.statusOf(seat)),
                                size: layout.seatSize,
                                onTap: () =>
                                    onSeatTap(seat, data.statusOf(seat)),
                              ),
                            ],
                            const SizedBox(width: _SeatMapLayout.labelGap),
                            _RowLabel(label: rowKey),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: AppSpacing.lg),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                            constraints.maxWidth - _SeatMapLayout.padding * 2,
                      ),
                      child: const SeatLegend(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Sizes the seat map so the widest row fits the screen: seats shrink on
// phones (down to [minSeat]) and grow up to [maxSeat] on larger screens.
class _SeatMapLayout {
  const _SeatMapLayout({required this.seatSize, required this.gap});

  factory _SeatMapLayout.fit({
    required double maxWidth,
    required int seatsPerRow,
  }) {
    final seats = math.max(seatsPerRow, 1);
    final gap = maxWidth < 600 ? 6.0 : AppSpacing.md;
    final available =
        maxWidth -
        padding * 2 -
        (labelWidth + labelGap) * 2 -
        gap * (seats - 1);

    return _SeatMapLayout(
      seatSize: (available / seats).clamp(minSeat, maxSeat).toDouble(),
      gap: gap,
    );
  }

  static const padding = AppSpacing.md;
  static const labelWidth = 20.0;
  static const labelGap = 6.0;
  static const minSeat = 20.0;
  static const maxSeat = 44.0;

  final double seatSize;
  final double gap;

  double seatsWidth(int seats) => seats * seatSize + (seats - 1) * gap;

  double mapWidth(int seats) {
    return seatsWidth(seats) + (labelWidth + labelGap) * 2 + padding * 2;
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _SeatMapLayout.labelWidth,
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ScreenIndicator extends StatelessWidget {
  const _ScreenIndicator({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomPaint(size: Size(width, 24), painter: _ScreenCurvePainter()),
        const SizedBox(height: AppSpacing.sm),
        const Text('SCREEN', style: AppTextStyles.caption),
      ],
    );
  }
}

class _ScreenCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withAlpha(128)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width / 2, 0, size.width, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
