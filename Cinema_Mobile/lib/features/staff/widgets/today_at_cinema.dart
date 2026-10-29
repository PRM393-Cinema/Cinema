import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/responsive_columns.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/room.dart';
import '../../../data/models/showtime.dart';
import '../../../data/services/staff_service.dart';
import '../../admin/widgets/admin_layout.dart';
import 'staff_feedback.dart';

enum _Phase { playing, next, finished }

// Today at the cinema, for the staff and admin dashboards: bookings made
// today, today's showtimes that have tickets, and a board of the showtimes
// playing now, coming next and just finished. Tapping a showtime opens its
// seat map with each customer's seats. Refreshes every minute.
class TodayAtCinema extends StatefulWidget {
  const TodayAtCinema({required this.service, this.refresh = 0, super.key});

  static const finishedShown = 3;
  static const nextShown = 3;

  final StaffService service;

  // The dashboard bumps it when pulled to refresh.
  final int refresh;

  @override
  State<TodayAtCinema> createState() => _TodayAtCinemaState();
}

class _TodayData {
  const _TodayData({
    required this.at,
    required this.tiles,
    required this.playing,
    required this.next,
    required this.finished,
    required this.stats,
    required this.movies,
    required this.rooms,
  });

  final DateTime at;
  final List<(String, Object, IconData)> tiles;
  final List<Showtime> playing;
  final List<Showtime> next;
  final List<Showtime> finished;
  final Map<int, ShowtimeBookingStats> stats;
  final Map<int, Movie> movies;
  final Map<int, Room> rooms;
}

class _TodayAtCinemaState extends State<TodayAtCinema> {
  static const _refreshEvery = Duration(minutes: 1);

  _TodayData? _data;
  String? _error;
  bool _loading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_refreshEvery, (_) => _load());
  }

  @override
  void didUpdateWidget(TodayAtCinema oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    final service = widget.service;
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    try {
      final bookings = await service.bookings(start: today, end: now);
      final todayShows = await service.showtimes(
        start: today,
        end: tomorrow,
        size: 1,
      );
      final todayStats = await service.showtimeStats(
        start: today,
        end: tomorrow,
      );
      // Long movies run up to about 3 hours: 12 hours back finds the shows
      // playing now and the ones that just finished.
      final window = [
        for (final show in await service.showtimesBetween(
          now.subtract(const Duration(hours: 12)),
          now.add(const Duration(hours: 12)),
        ))
          if (show.status != 'CANCELLED') show,
      ];
      final playing = [
        for (final show in window)
          if (!show.startTime.isAfter(now) && show.endTime.isAfter(now)) show,
      ];
      final next = window
          .where((show) => show.startTime.isAfter(now))
          .take(TodayAtCinema.nextShown)
          .toList();
      final finished =
          (window.where((show) => !show.endTime.isAfter(now)).toList()
                ..sort((a, b) => b.endTime.compareTo(a.endTime)))
              .take(TodayAtCinema.finishedShown)
              .toList();
      final board = [...playing, ...next, ...finished];
      final stats = board.isEmpty
          ? const <ShowtimeBookingStats>[]
          : await service.showtimeStats(ids: [for (final s in board) s.id]);
      final movies = (await service.movies()).items;
      final rooms = (await service.rooms(size: 50)).items;

      final withTickets = todayStats
          .where((s) => s.soldSeats + s.heldSeats > 0)
          .length;
      final sold = todayStats.fold(0, (total, s) => total + s.soldSeats);
      final checkedIn = todayStats.fold(
        0,
        (total, s) => total + s.checkedInSeats,
      );
      if (!mounted) return;
      setState(() {
        _error = null;
        _data = _TodayData(
          at: now,
          tiles: [
            (
              'Bookings today',
              bookings.totalCount,
              Icons.confirmation_number_outlined,
            ),
            (
              'Showtimes with bookings',
              '$withTickets / ${todayShows.totalCount}',
              Icons.event_available_outlined,
            ),
            ('Tickets for today’s shows', sold, Icons.local_activity_outlined),
            (
              'Checked in for today’s shows',
              checkedIn,
              Icons.how_to_reg_outlined,
            ),
          ],
          playing: playing,
          next: next,
          finished: finished,
          stats: {for (final s in stats) s.showtimeId: s},
          movies: {for (final movie in movies) movie.id: movie},
          rooms: {for (final room in rooms) room.id: room},
        );
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final error = _error;

    return Column(
      key: const Key('todayAtCinema'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Today', style: AppTextStyles.title)),
            if (data != null)
              Text(
                'Updated ${formatTime(data.at)}',
                style: AppTextStyles.caption,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Bookings made today, today’s showtimes with tickets, and the '
          'showtimes playing now, next and just finished. Open a showtime to '
          'see where its customers sit.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),
        if (data == null && error == null)
          const Center(child: CircularProgressIndicator())
        else if (data == null)
          Text(
            'Today’s figures could not be loaded: $error',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
          )
        else ...[
          StatTiles(key: const Key('todayStats'), tiles: data.tiles),
          const SizedBox(height: AppSpacing.xl),
          _Group(
            title: 'Now showing',
            empty: 'No showtime is playing right now.',
            phase: _Phase.playing,
            showtimes: data.playing,
            data: data,
          ),
          _Group(
            title: 'Up next',
            empty: 'No more showtimes in the next 12 hours.',
            phase: _Phase.next,
            showtimes: data.next,
            data: data,
          ),
          _Group(
            title: 'Just finished',
            empty: 'No showtime finished in the last 12 hours.',
            phase: _Phase.finished,
            showtimes: data.finished,
            data: data,
          ),
        ],
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.empty,
    required this.phase,
    required this.showtimes,
    required this.data,
  });

  final String title;
  final String empty;
  final _Phase phase;
  final List<Showtime> showtimes;
  final _TodayData data;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$title (${showtimes.length})',
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),
        if (showtimes.isEmpty)
          Text(empty, style: AppTextStyles.bodySmall)
        else
          CardColumns(
            minCardWidth: 340,
            children: [
              for (final show in showtimes)
                _ShowtimeCard(
                  showtime: show,
                  phase: phase,
                  now: data.at,
                  movie: data.movies[show.movieId],
                  room: data.rooms[show.roomId],
                  stats:
                      data.stats[show.id] ??
                      ShowtimeBookingStats(showtimeId: show.id),
                ),
            ],
          ),
      ],
    ),
  );
}

class _ShowtimeCard extends StatelessWidget {
  const _ShowtimeCard({
    required this.showtime,
    required this.phase,
    required this.now,
    required this.movie,
    required this.room,
    required this.stats,
  });

  final Showtime showtime;
  final _Phase phase;
  final DateTime now;
  final Movie? movie;
  final Room? room;
  final ShowtimeBookingStats stats;

  String _time(DateTime value) => DateUtils.isSameDay(value, now)
      ? formatTime(value)
      : '${formatShortDate(value)} ${formatTime(value)}';

  static String _minutes(Duration value) {
    final minutes = value.inMinutes;
    return minutes < 60
        ? '$minutes min'
        : '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final start = showtime.startTime;
    final end = showtime.endTime;
    final length = movie?.durationText ?? _minutes(end.difference(start));
    final capacity = room?.totalSeats;
    final running = end.difference(start);
    final (badge, variant) = switch (phase) {
      _Phase.playing => ('Now showing', StatusBadgeVariant.success),
      _Phase.next => (
        'Starts in ${_minutes(start.difference(now))}',
        StatusBadgeVariant.warning,
      ),
      _Phase.finished => (
        'Ended ${_minutes(now.difference(end))} ago',
        StatusBadgeVariant.neutral,
      ),
    };
    final counts = switch (phase) {
      _Phase.next => [
        ('${stats.soldSeats}', 'booked'),
        if (stats.heldSeats > 0) ('${stats.heldSeats}', 'awaiting payment'),
        if (stats.checkedInSeats > 0) ('${stats.checkedInSeats}', 'checked in'),
        if (capacity != null)
          ('${stats.soldSeats + stats.heldSeats}/$capacity', 'seats taken'),
      ],
      _Phase.playing => [
        ('${stats.checkedInSeats}', 'watching now'),
        (
          capacity == null
              ? '${stats.soldSeats}'
              : '${stats.soldSeats}/$capacity',
          'tickets sold',
        ),
      ],
      _Phase.finished => [
        ('${stats.soldSeats}', 'tickets sold'),
        ('${stats.checkedInSeats}', 'came in'),
      ],
    };

    return InkWell(
      key: ValueKey('boardShowtime-${showtime.id}'),
      borderRadius: AppRadius.borderRadiusMd,
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.staffRecord('showtimes', showtime.id),
      ),
      child: CinemaPanel(
        surfaceOpacity: 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    movie?.title ?? 'Movie #${showtime.movieId}',
                    style: AppTextStyles.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(label: badge, variant: variant),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${room?.name ?? showtime.roomLabel} • ${_time(start)} – '
              '${_time(end)} • $length',
              style: AppTextStyles.bodySmall,
            ),
            if (phase == _Phase.playing) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: running.inSeconds <= 0
                      ? 0
                      : now.difference(start).inSeconds / running.inSeconds,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${_minutes(end.difference(now))} left',
                style: AppTextStyles.caption,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (value, label) in counts)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: AppTextStyles.heading2.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      Text(label, style: AppTextStyles.caption),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
