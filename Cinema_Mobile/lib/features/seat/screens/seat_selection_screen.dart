import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/cinema_page.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/top_notice.dart';
import '../../../data/models/booking_draft.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/seat.dart';
import '../../../data/models/showtime.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../widgets/seat_item.dart';
import '../widgets/seat_legend.dart';
import '../widgets/seat_map_rows.dart';
import '../widgets/seat_type_style.dart';

class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({
    required this.catalogRepository,
    this.showtimeId,
    super.key,
  });

  final CatalogRepository catalogRepository;

  // Set when the screen is opened from its URL: the showtime and its movie
  // are loaded by id.
  final int? showtimeId;

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  // Seats taken by other customers show up while the map is open.
  static const _liveInterval = Duration(seconds: 5);

  final Set<int> _selectedSeatIds = {};
  bool _showtimeRequested = false;
  SeatSelectionArgs? _args;
  ShowtimeSeatsData? _data;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _liveTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _liveTimer = Timer.periodic(_liveInterval, (_) => _refreshSeatMap());
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (_args == null && args is SeatSelectionArgs) {
      _args = args;
      _loadSeatMap();
    } else if (_args == null &&
        !_showtimeRequested &&
        widget.showtimeId != null) {
      _showtimeRequested = true;
      _loadShowtime();
    }
  }

  // Opened from its URL (web refresh or shared link): load the showtime and
  // its movie, then the seat map.
  Future<void> _loadShowtime() async {
    try {
      final catalog = widget.catalogRepository;
      final showtime = await catalog.getShowtime(widget.showtimeId!);
      final movie = await catalog.getMovie(showtime.movieId);
      if (!mounted) return;
      _args = SeatSelectionArgs(movie: movie, showtime: showtime);
      await _loadSeatMap();
    } on ApiException catch (error) {
      _showError(error.message);
    } on FormatException {
      _showError('The server returned an invalid response.');
    } on Object {
      _showError('Something went wrong. Please try again.');
    }
  }

  void _retryShowtime() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _loadShowtime();
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
      if (mounted) _showSeatMap(data);
    } on ApiException catch (error) {
      _showError(error.message);
    } on FormatException {
      _showError('The server returned an invalid response.');
    } on Object {
      _showError('Something went wrong. Please try again.');
    }
  }

  // Reloads the seat map in the background while this page is on top (not
  // under the booking summary). A failed refresh keeps the last map.
  Future<void> _refreshSeatMap() async {
    final args = _args;
    if (args == null ||
        _data == null ||
        _isLoading ||
        _refreshing ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _refreshing = true;
    try {
      final data = await widget.catalogRepository.getSeatMap(args.showtime);
      if (mounted && !_isLoading) _showSeatMap(data, notify: true);
    } on Object {
      // Keep the last seat map; the next refresh tries again.
    } finally {
      _refreshing = false;
    }
  }

  // Shows a newer seat map. Selected seats that are no longer free (someone
  // else took them) are let go, with the other half of their sweetbox; with
  // [notify] the customer is told which.
  void _showSeatMap(ShowtimeSeatsData data, {bool notify = false}) {
    final selected = _selectedSeats(_data);
    final free = {
      for (final seat in data.seats)
        if (data.statusOf(seat) == SeatReservationStatus.available) seat.id,
    };
    setState(() {
      _data = data;
      _isLoading = false;
      _selectedSeatIds.removeWhere((id) => !free.contains(id));
      _selectedSeatIds.removeWhere((id) {
        final seat = data.seats.where((s) => s.id == id).firstOrNull;
        final partner = seat?.sweetboxPartnerIn(data.seats);
        return partner != null && !_selectedSeatIds.contains(partner.id);
      });
    });
    final lost = [
      for (final seat in selected)
        if (!_selectedSeatIds.contains(seat.id)) seat.label,
    ];
    if (notify && lost.isNotEmpty) {
      showTopNotice(
        Overlay.of(context, rootOverlay: true),
        lost.length == 1
            ? '${lost.single} was just taken, so it was removed from your '
                  'seats.'
            : '${lost.join(', ')} were just taken, so they were removed from '
                  'your seats.',
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  // A sweetbox is a couple seat: picking either half picks both (1 with 2,
  // 4 with 3), and so does letting it go.
  void _toggleSeat(Seat seat, SeatReservationStatus status) {
    final data = _data;
    if (data == null ||
        status == SeatReservationStatus.held ||
        status == SeatReservationStatus.booked) {
      return; // Cannot select
    }
    final partner = seat.sweetboxPartnerIn(data.seats);
    if (_selectedSeatIds.contains(seat.id)) {
      setState(() {
        _selectedSeatIds.remove(seat.id);
        if (partner != null) _selectedSeatIds.remove(partner.id);
      });
      return;
    }
    if (partner != null &&
        data.statusOf(partner) != SeatReservationStatus.available) {
      showTopNotice(
        Overlay.of(context, rootOverlay: true),
        '${seat.label} is a sweetbox (couple seat) and ${partner.label} is '
        'taken, so it cannot be booked.',
      );
      return;
    }
    setState(() {
      _selectedSeatIds.add(seat.id);
      if (partner != null) _selectedSeatIds.add(partner.id);
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
      AppRoutes.bookingSummary(args.showtime.id),
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
      final error = _errorMessage;
      return CinemaPage(
        title: 'Seat Selection',
        child: _showtimeRequested && _isLoading
            ? const LoadingState(message: 'Loading showtime...')
            : _showtimeRequested && error != null
            ? ErrorState(
                title: 'Unable to load the showtime',
                message: error,
                onRetry: _retryShowtime,
              )
            : const ErrorState(
                title: 'Showtime not found',
                message: 'Please return and select a showtime again.',
              ),
      );
    }

    final showtime = args.showtime;
    final data = _data;
    final selectedSeats = _selectedSeats(data);
    final totalPrice = selectedSeats.fold(
      0.0,
      (total, seat) => total + showtime.priceOf(seat.type),
    );
    final selectedLabels = selectedSeats.map((seat) => seat.label).join(', ');
    final onContinue = data != null && _selectedSeatIds.isNotEmpty
        ? () => _continue(args, data)
        : null;

    if (isDesktopLayout(context)) {
      // Website: the seat map with the order summary next to it.
      return Scaffold(
        body: CinemaBackground(
          child: SafeArea(
            child: Padding(
              padding: pagePadding(context, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Select Seats', style: AppTextStyles.heading2),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CinemaPanel(
                            surfaceOpacity: 0.45,
                            child: _buildSeatMap(showtime, data),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xl),
                        SizedBox(
                          width: 360,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CinemaPanel(
                                  padding: EdgeInsets.zero,
                                  surfaceOpacity: 0.8,
                                  child: _ShowtimeSummary(
                                    movie: args.movie,
                                    showtime: showtime,
                                    seats: data?.seats,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                CinemaPanel(
                                  surfaceOpacity: 0.8,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text(
                                        'Your seats',
                                        style: AppTextStyles.title,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        selectedLabels.isEmpty
                                            ? 'Choose your seats on the map.'
                                            : selectedLabels,
                                        style: selectedLabels.isEmpty
                                            ? AppTextStyles.bodySmall
                                            : AppTextStyles.body,
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      Row(
                                        children: [
                                          Text(
                                            '${_selectedSeatIds.length} seat(s)',
                                            style: AppTextStyles.bodySmall,
                                          ),
                                          const Spacer(),
                                          Text(
                                            formatVnd(totalPrice),
                                            style: AppTextStyles.heading2
                                                .copyWith(
                                                  color: AppColors.primary,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      AppButton(
                                        label: 'Continue',
                                        useGradient: true,
                                        trailingIcon:
                                            Icons.arrow_forward_rounded,
                                        onPressed: onContinue,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: CinemaBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Select Seats', style: AppTextStyles.heading2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: CinemaPanel(
                  padding: EdgeInsets.zero,
                  surfaceOpacity: 0.8,
                  child: _ShowtimeSummary(
                    movie: args.movie,
                    showtime: showtime,
                    seats: data?.seats,
                  ),
                ),
              ),
              Expanded(child: _buildSeatMap(showtime, data)),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: CinemaPanel(
                  surfaceOpacity: 0.72,
                  padding: const EdgeInsets.all(AppSpacing.md),
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
                                      // Both parts shorten next to the
                                      // Continue button on narrow phones.
                                      Flexible(
                                        child: Text(
                                          '${_selectedSeatIds.length} seat(s)',
                                          style: AppTextStyles.bodySmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (selectedLabels.isNotEmpty)
                                        Flexible(
                                          child: Text(
                                            ' • $selectedLabels',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
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
                                      style: AppTextStyles.heading2.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            AppButton(
                              label: 'Continue',
                              useGradient: true,
                              trailingIcon: Icons.arrow_forward_rounded,
                              onPressed: onContinue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeatMap(Showtime showtime, ShowtimeSeatsData? data) {
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
      showtime: showtime,
      selectedSeatIds: _selectedSeatIds,
      onSeatTap: _toggleSeat,
    );
  }
}

// What is being booked: shown above the seat map.
class _ShowtimeSummary extends StatelessWidget {
  const _ShowtimeSummary({
    required this.movie,
    required this.showtime,
    this.seats,
  });

  final Movie movie;
  final Showtime showtime;

  // The seats of the room once loaded: the price is the one of their types.
  final List<Seat>? seats;

  @override
  Widget build(BuildContext context) {
    final price = seatPriceLabel(
      showtime,
      types: seats?.map((seat) => seat.type),
    );
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
                  '${showtime.roomLabel} • $price',
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
    required this.showtime,
    required this.selectedSeatIds,
    required this.onSeatTap,
  });

  final ShowtimeSeatsData data;
  final Showtime showtime;
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
    final rows = seatRowsOf(data.seats);
    final seatsPerRow = widestRowOf(rows);
    final types = {for (final seat in data.seats) seat.type.toUpperCase()};
    // Prices tell the seat types apart only when they differ.
    final showPrices = seatPricesOf(showtime, types: types).length > 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = SeatMapLayout.fit(
          maxWidth: constraints.maxWidth,
          seatsPerRow: seatsPerRow,
        );
        final fitsScreen = layout.mapWidth(seatsPerRow) <= constraints.maxWidth;
        final legend = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth - SeatMapLayout.padding * 2,
          ),
          child: SeatLegend(
            types: types,
            priceOf: showPrices ? showtime.priceOf : null,
          ),
        );

        Widget viewer(
          BoxConstraints box, {
          Widget? legend,
        }) => InteractiveViewer(
          // Pinch to zoom in on small seats; very wide rooms can also be
          // zoomed out and panned.
          minScale: fitsScreen ? 1 : 0.5,
          maxScale: 3,
          constrained: false,
          // Small rooms sit in the middle of the free space instead of
          // leaving a gap below the seats.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: box.maxWidth,
              minHeight: box.maxHeight,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(SeatMapLayout.padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SeatScreenIndicator(width: layout.seatsWidth(seatsPerRow)),
                    const SizedBox(height: AppSpacing.sm),
                    // Wraps instead of widening the column: the map is
                    // laid out unconstrained, so a long line would push
                    // the seats off-centre (large text sizes, narrow
                    // phones).
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: box.maxWidth - SeatMapLayout.padding * 2,
                      ),
                      child: Text(
                        '${rows.length} rows • ${data.seats.length} seats • Pinch to zoom',
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SeatMapRows(
                      rows: rows,
                      layout: layout,
                      seatBuilder: (seat, size) => SeatItem(
                        label: seat.number.toString(),
                        state: _itemStateOf(seat, data.statusOf(seat)),
                        type: seat.type,
                        size: size,
                        onTap: () => onSeatTap(seat, data.statusOf(seat)),
                      ),
                    ),
                    if (legend != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      legend,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );

        if (fitsScreen) return viewer(constraints, legend: legend);
        // A map wider than the screen is panned: its key stays in view below
        // it instead of moving (and being cut off) with the seats.
        return Column(
          children: [
            Expanded(child: LayoutBuilder(builder: (_, box) => viewer(box))),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SeatMapLayout.padding,
              ),
              child: legend,
            ),
          ],
        );
      },
    );
  }
}
