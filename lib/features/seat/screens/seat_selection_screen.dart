import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_state.dart';
import '../../../data/mock/mock_movies.dart';
import '../../../data/mock/mock_seats.dart';
import '../../../data/models/seat.dart';
import '../../../data/models/showtime.dart';
import '../widgets/seat_item.dart';
import '../widgets/seat_legend.dart';

class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({super.key});

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  final Set<String> _selectedSeatIds = {};

  void _toggleSeat(Seat seat, SeatReservationStatus status) {
    if (status == SeatReservationStatus.held || status == SeatReservationStatus.booked) {
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

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! Showtime) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seat Selection')),
        body: const ErrorState(
          title: 'Showtime not found',
          message: 'Please return and select a showtime again.',
        ),
      );
    }

    final showtime = args;
    final movie = mockMovies.firstWhere(
      (m) => m.id == showtime.movieId,
      orElse: () => mockMovies.first,
    );
    final data = mockShowtimeSeatsData;

    final totalPrice = _selectedSeatIds.length * showtime.price;
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(movie.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              '${dateFormat.format(showtime.startTime)} • ${timeFormat.format(showtime.startTime)} • ${showtime.roomId}',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _SeatMap(
                data: data,
                selectedSeatIds: _selectedSeatIds,
                onSeatTap: _toggleSeat,
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              color: AppColors.surface,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SeatLegend(),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_selectedSeatIds.length} seat(s)',
                              style: AppTextStyles.bodySmall,
                            ),
                            Text(
                              '\$${totalPrice.toStringAsFixed(2)}',
                              style: AppTextStyles.heading2,
                            ),
                          ],
                        ),
                        AppButton(
                          label: 'Continue',
                          onPressed: _selectedSeatIds.isNotEmpty
                              ? () {
                                  // Pass necessary payload for the next phase
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.bookingSummary,
                                    arguments: {
                                      'showtime': showtime,
                                      'seats': data.seats
                                          .where((s) => _selectedSeatIds.contains(s.id))
                                          .toList(),
                                    },
                                  );
                                }
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
}

class _SeatMap extends StatelessWidget {
  const _SeatMap({
    required this.data,
    required this.selectedSeatIds,
    required this.onSeatTap,
  });

  final ShowtimeSeatsData data;
  final Set<String> selectedSeatIds;
  final void Function(Seat seat, SeatReservationStatus status) onSeatTap;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 2.0,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(AppSpacing.xxxl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                children: [
                  _ScreenIndicator(),
                  const SizedBox(height: AppSpacing.xxxl),
                  ...sortedRowKeys.map((rowKey) {
                    final rowSeats = rows[rowKey]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: AppSpacing.xxl,
                            child: Text(
                              rowKey,
                              style: AppTextStyles.title,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          ...rowSeats.map((seat) {
                            final status = data.reservations[seat.id] ??
                                SeatReservationStatus.available;
                            final isSelected = selectedSeatIds.contains(seat.id);

                            SeatItemState itemState;
                            if (isSelected) {
                              itemState = SeatItemState.selected;
                            } else if (status == SeatReservationStatus.held) {
                              itemState = SeatItemState.held;
                            } else if (status == SeatReservationStatus.booked) {
                              itemState = SeatItemState.booked;
                            } else {
                              itemState = SeatItemState.available;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.md),
                              child: SeatItem(
                                label: seat.number.toString(),
                                state: itemState,
                                onTap: () => onSeatTap(seat, status),
                              ),
                            );
                          }),
                          const SizedBox(width: AppSpacing.md),
                          SizedBox(
                            width: AppSpacing.xxl,
                            child: Text(
                              rowKey,
                              style: AppTextStyles.title,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScreenIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomPaint(
          size: const Size(300, 30),
          painter: _ScreenCurvePainter(),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'SCREEN',
          style: AppTextStyles.caption,
        ),
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
