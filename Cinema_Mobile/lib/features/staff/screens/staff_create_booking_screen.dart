import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/seat.dart';
import '../../../data/models/showtime.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/services/staff_service.dart';
import '../../admin/widgets/admin_page.dart';
import '../../seat/widgets/seat_item.dart';
import '../../seat/widgets/seat_legend.dart';
import '../../seat/widgets/seat_map_rows.dart';
import '../../seat/widgets/seat_type_style.dart';
import '../widgets/staff_feedback.dart';

// Booking at the counter: the customer's account, then a movie, one of its
// showtimes in the coming week and seats on the room's seat map.
class StaffCreateBookingScreen extends StatefulWidget {
  const StaffCreateBookingScreen({
    required this.service,
    required this.catalog,
    super.key,
  });
  final StaffService service;
  final CatalogRepository catalog;
  @override
  State<StaffCreateBookingScreen> createState() =>
      _StaffCreateBookingScreenState();
}

class _StaffCreateBookingScreenState extends State<StaffCreateBookingScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _email = TextEditingController();
  List<Movie>? _movies;
  Movie? _movie;
  List<Showtime>? _showtimes;
  Showtime? _showtime;
  ShowtimeSeatsData? _map;
  final _selected = <int>{};
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  @override
  void dispose() {
    _user.dispose();
    _email.dispose();
    super.dispose();
  }

  String? _id(String? value) =>
      (int.tryParse(value?.trim() ?? '') ?? 0) > 0 ? null : 'Enter a valid ID.';

  // The price of the picked seats, each by its type, as the server prices the
  // booking.
  double _totalOf(Showtime showtime, ShowtimeSeatsData map) => map.seats
      .where((seat) => _selected.contains(seat.id))
      .fold(0, (total, seat) => total + showtime.priceOf(seat.type));

  // A sweetbox is booked as a couple: its other half is picked with it.
  void _toggle(ShowtimeSeatsData map, Seat seat) {
    final partner = seat.sweetboxPartnerIn(map.seats);
    setState(() {
      _error = null;
      if (_selected.remove(seat.id)) {
        if (partner != null) _selected.remove(partner.id);
      } else if (partner != null &&
          map.statusOf(partner) != SeatReservationStatus.available) {
        _error =
            '${seat.label} is a sweetbox (couple seat) and ${partner.label} '
            'is taken.';
      } else {
        _selected.add(seat.id);
        if (partner != null) _selected.add(partner.id);
      }
    });
  }

  Future<void> _run(Future<void> Function() load) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await load();
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadMovies() => _run(() async {
    final movies = await widget.catalog.getNowShowingMovies();
    if (mounted) setState(() => _movies = movies);
  });

  Future<void> _pickMovie(Movie? movie) async {
    setState(() {
      _movie = movie;
      _showtimes = null;
      _showtime = null;
      _map = null;
      _selected.clear();
    });
    if (movie == null) return;
    await _run(() async {
      final showtimes = await widget.catalog.getOpenShowtimes(movie.id);
      final now = DateTime.now();
      if (mounted && _movie == movie) {
        setState(
          () => _showtimes = [
            for (final show in showtimes)
              if (show.isOpen && show.startTime.isAfter(now)) show,
          ],
        );
      }
    });
  }

  Future<void> _pickShowtime(Showtime? show) async {
    setState(() {
      _showtime = show;
      _map = null;
      _selected.clear();
    });
    if (show == null) return;
    await _run(() async {
      final map = await widget.catalog.getSeatMap(show);
      if (mounted && _showtime == show) setState(() => _map = map);
    });
  }

  Future<void> _create() async {
    if (_busy ||
        !_form.currentState!.validate() ||
        _showtime == null ||
        _selected.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await staffConfirm(
            context,
            'Hold seats for customer?',
            'Create a booking for customer #${_user.text.trim()} with tickets sent to ${_email.text.trim()}. Seats are held for 10 minutes; payment is still required.',
          ) ||
          !mounted) {
        return;
      }

      final booking = await widget.service.createBooking(
        userId: int.parse(_user.text.trim()),
        email: _email.text.trim(),
        showtimeId: _showtime!.id,
        seats: _selected.toList(),
      );
      if (!mounted) return;
      await staffSuccess(
        context,
        'Booking created. Complete payment before the hold expires.',
      );
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.staffRecord('bookings', booking.id),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _showtimeLabel(Showtime show) =>
      '${formatShortDate(show.startTime)} • ${formatTime(show.startTime)} • '
      '${show.roomLabel} • ${seatPriceLabel(show)}';

  @override
  Widget build(BuildContext context) {
    final movies = _movies;
    final showtimes = _showtimes;
    final showtime = _showtime;
    final map = _map;

    return AdminPage(
      title: 'Book for customer',
      section: AdminSection.operations,
      child: SingleChildScrollView(
        padding: staffPadding(context),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CinemaPanel(
                surfaceOpacity: 0.8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Customer', style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Use the customer’s account ID and email, not the staff '
                      'account.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Customer account ID',
                      controller: _user,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      validator: _id,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Customer email',
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value?.trim() ?? '') &&
                              (value?.trim().length ?? 0) <= 150
                          ? null
                          : 'Enter a valid email.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              CinemaPanel(
                surfaceOpacity: 0.8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Showtime', style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<Movie>(
                      key: const Key('bookingMovie'),
                      initialValue: _movie,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Movie'),
                      hint: Text(
                        movies == null ? 'Loading movies…' : 'Choose a movie',
                      ),
                      items: [
                        for (final movie in movies ?? const <Movie>[])
                          DropdownMenuItem(
                            value: movie,
                            child: Text(
                              movie.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _busy ? null : _pickMovie,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<Showtime>(
                      key: ValueKey('bookingShowtime-${_movie?.id}'),
                      initialValue: showtime,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Showtime (next 7 days)',
                      ),
                      hint: Text(
                        _movie == null
                            ? 'Choose a movie first'
                            : showtimes == null
                            ? 'Loading showtimes…'
                            : showtimes.isEmpty
                            ? 'No open showtimes in the coming week'
                            : 'Choose a showtime',
                      ),
                      items: [
                        for (final show in showtimes ?? const <Showtime>[])
                          DropdownMenuItem(
                            value: show,
                            child: Text(
                              _showtimeLabel(show),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      validator: (value) =>
                          value == null ? 'Choose a showtime.' : null,
                      onChanged: _busy ? null : _pickShowtime,
                    ),
                  ],
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (showtime != null && map != null) ...[
                const SizedBox(height: AppSpacing.lg),
                CinemaPanel(
                  surfaceOpacity: 0.8,
                  child: _CounterSeatMap(
                    showtime: showtime,
                    map: map,
                    selected: _selected,
                    onTap: _busy ? null : (seat) => _toggle(map, seat),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${_selected.length} seat(s) selected · '
                  '${formatVnd(_totalOf(showtime, map))}',
                  key: const Key('counterTotal'),
                  style: AppTextStyles.title,
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    _error!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Create booking',
                useGradient: true,
                isLoading: _busy,
                onPressed: _busy || _selected.isEmpty ? null : _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The room of the chosen showtime: free seats by type (sweetbox pairs joined),
// taken seats greyed, the counter's picks highlighted.
class _CounterSeatMap extends StatelessWidget {
  const _CounterSeatMap({
    required this.showtime,
    required this.map,
    required this.selected,
    required this.onTap,
  });

  final Showtime showtime;
  final ShowtimeSeatsData map;
  final Set<int> selected;
  final void Function(Seat seat)? onTap;

  @override
  Widget build(BuildContext context) {
    final rows = seatRowsOf(map.seats);
    final widest = widestRowOf(rows);
    final types = {for (final seat in map.seats) seat.type.toUpperCase()};
    final showPrices = seatPricesOf(showtime, types: types).length > 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = SeatMapLayout.fit(
          maxWidth: constraints.maxWidth,
          seatsPerRow: widest,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${showtime.roomLabel} · ${formatDateTime(showtime.startTime)}',
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            // Very wide rooms scroll sideways instead of shrinking seats
            // below a tappable size.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(SeatMapLayout.padding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SeatScreenIndicator(width: layout.seatsWidth(widest)),
                        const SizedBox(height: AppSpacing.xl),
                        SeatMapRows(
                          rows: rows,
                          layout: layout,
                          seatBuilder: (seat, size) => SeatItem(
                            key: ValueKey('counterSeat-${seat.label}'),
                            label: seat.number.toString(),
                            state:
                                map.statusOf(seat) !=
                                    SeatReservationStatus.available
                                ? SeatItemState.booked
                                : selected.contains(seat.id)
                                ? SeatItemState.selected
                                : SeatItemState.available,
                            type: seat.type,
                            size: size,
                            onTap: onTap == null ? null : () => onTap!(seat),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SeatLegend(
              types: types,
              priceOf: showPrices ? showtime.priceOf : null,
            ),
          ],
        );
      },
    );
  }
}
