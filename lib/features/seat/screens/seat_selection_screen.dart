import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/booking_draft.dart';
import '../../../data/models/seat.dart';
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

  Future<void> _continue(SeatSelectionArgs args, ShowtimeSeatsData data) async {
    final seats =
        data.seats.where((s) => _selectedSeatIds.contains(s.id)).toList()
          ..sort((a, b) => a.label.compareTo(b.label));

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

    return Scaffold(
      appBar: AppBar(
        title: Text(args.movie.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              '${formatDate(showtime.startTime)} • ${formatTime(showtime.startTime)} • ${showtime.roomLabel}',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildSeatMap(data)),
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
                              formatVnd(totalPrice),
                              style: AppTextStyles.heading2,
                            ),
                          ],
                        ),
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

class _SeatMap extends StatelessWidget {
  const _SeatMap({
    required this.data,
    required this.selectedSeatIds,
    required this.onSeatTap,
  });

  final ShowtimeSeatsData data;
  final Set<int> selectedSeatIds;
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
                            final status = data.statusOf(seat);
                            final isSelected = selectedSeatIds.contains(
                              seat.id,
                            );

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
                              padding: const EdgeInsets.only(
                                right: AppSpacing.md,
                              ),
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
        CustomPaint(size: const Size(300, 30), painter: _ScreenCurvePainter()),
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
