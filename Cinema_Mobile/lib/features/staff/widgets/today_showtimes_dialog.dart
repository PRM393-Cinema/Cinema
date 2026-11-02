import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/room.dart';
import '../../../data/models/showtime.dart';
import '../../../data/services/staff_service.dart';
import 'staff_feedback.dart';

enum ShowtimePhase { playing, upcoming, finished, cancelled }

ShowtimePhase showtimePhase(Showtime show, DateTime now) {
  if (show.status == 'CANCELLED') return ShowtimePhase.cancelled;
  if (show.startTime.isAfter(now)) return ShowtimePhase.upcoming;
  if (show.endTime.isAfter(now)) return ShowtimePhase.playing;
  return ShowtimePhase.finished;
}

const _phaseLabels = {
  ShowtimePhase.playing: 'Now showing',
  ShowtimePhase.upcoming: 'Upcoming',
  ShowtimePhase.finished: 'Finished',
  ShowtimePhase.cancelled: 'Cancelled',
};

const _phaseBadges = {
  ShowtimePhase.playing: StatusBadgeVariant.success,
  ShowtimePhase.upcoming: StatusBadgeVariant.warning,
  ShowtimePhase.finished: StatusBadgeVariant.neutral,
  ShowtimePhase.cancelled: StatusBadgeVariant.error,
};

// Every showtime of today (the dashboard board only shows the ones around
// now), with filters for the movie, the room, the phase and shows that have
// tickets. Tapping a showtime opens its seat map.
Future<void> showTodayShowtimes(
  BuildContext context, {
  required StaffService service,
  Map<int, Movie> movies = const {},
  Map<int, Room> rooms = const {},
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      TodayShowtimesDialog(service: service, movies: movies, rooms: rooms),
);

class TodayShowtimesDialog extends StatefulWidget {
  const TodayShowtimesDialog({
    required this.service,
    this.movies = const {},
    this.rooms = const {},
    super.key,
  });

  final StaffService service;

  // Names already loaded by the dashboard; loaded here when empty.
  final Map<int, Movie> movies;
  final Map<int, Room> rooms;

  @override
  State<TodayShowtimesDialog> createState() => _TodayShowtimesDialogState();
}

class _TodayShowtimesDialogState extends State<TodayShowtimesDialog> {
  final _search = TextEditingController();
  late DateTime _now = DateTime.now();
  List<Showtime>? _shows;
  Map<int, ShowtimeBookingStats> _stats = const {};
  late Map<int, Movie> _movies = widget.movies;
  late Map<int, Room> _rooms = widget.rooms;
  String? _error;

  ShowtimePhase? _phase;
  int? _roomId;
  bool _withTickets = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final service = widget.service;
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    setState(() => _error = null);
    try {
      final shows = await service.showtimesBetween(today, tomorrow);
      final stats = await service.showtimeStats(start: today, end: tomorrow);
      final movies = _movies.isNotEmpty
          ? _movies
          : {
              for (final movie in (await service.movies()).items)
                movie.id: movie,
            };
      final rooms = _rooms.isNotEmpty
          ? _rooms
          : {
              for (final room in (await service.rooms(size: 50)).items)
                room.id: room,
            };
      if (!mounted) return;
      setState(() {
        _now = now;
        _shows = shows..sort((a, b) => a.startTime.compareTo(b.startTime));
        _stats = {for (final row in stats) row.showtimeId: row};
        _movies = movies;
        _rooms = rooms;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    }
  }

  String _title(Showtime show) =>
      _movies[show.movieId]?.title ?? 'Movie #${show.movieId}';

  String _roomName(Showtime show) =>
      _rooms[show.roomId]?.name ?? show.roomLabel;

  bool _hasTickets(Showtime show) {
    final stats = _stats[show.id];
    return stats != null && stats.soldSeats + stats.heldSeats > 0;
  }

  // Every filter except the phase, so the phase chips can show their counts.
  List<Showtime> _matching(List<Showtime> shows) {
    final query = _search.text.trim().toLowerCase();
    return [
      for (final show in shows)
        if ((query.isEmpty || _title(show).toLowerCase().contains(query)) &&
            (_roomId == null || show.roomId == _roomId) &&
            (!_withTickets || _hasTickets(show)))
          show,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 600;
    final shows = _shows;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.xl),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: size.height * 0.9,
        ),
        child: CinemaPanel(
          child: Column(
            key: const Key('todayShowtimesDialog'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'All showtimes today',
                      style: AppTextStyles.heading2,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: shows == null && _error == null ? null : _load,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(formatLongDate(_now), style: AppTextStyles.bodySmall),
              const SizedBox(height: AppSpacing.md),
              if (_error != null)
                Text(
                  'Today’s showtimes could not be loaded: $_error',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppPalette.of(context).error,
                  ),
                )
              else if (shows == null)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ..._content(shows, compact),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(List<Showtime> shows, bool compact) {
    final matching = _matching(shows);
    final counts = {
      for (final phase in ShowtimePhase.values)
        phase: matching.where((s) => showtimePhase(s, _now) == phase).length,
    };
    final visible = [
      for (final show in matching)
        if (_phase == null || showtimePhase(show, _now) == _phase) show,
    ];
    final roomIds = {for (final show in shows) show.roomId}.toList()
      ..sort(
        (a, b) => (_rooms[a]?.name ?? '$a').compareTo(_rooms[b]?.name ?? '$b'),
      );

    return [
      Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: compact ? double.infinity : 280,
            child: AppTextField(
              key: const Key('todayShowtimesSearch'),
              label: 'Search movies',
              controller: _search,
              prefixIcon: const Icon(Icons.search),
              onChanged: (_) => setState(() {}),
            ),
          ),
          DropdownButton<int?>(
            key: const Key('todayShowtimesRoom'),
            value: _roomId,
            hint: const Text('All rooms'),
            items: [
              const DropdownMenuItem<int?>(child: Text('All rooms')),
              for (final id in roomIds)
                DropdownMenuItem<int?>(
                  value: id,
                  child: Text(_rooms[id]?.name ?? 'Room #$id'),
                ),
            ],
            onChanged: (value) => setState(() => _roomId = value),
          ),
          FilterChip(
            key: const Key('todayShowtimesWithTickets'),
            label: const Text('With tickets'),
            selected: _withTickets,
            onSelected: (value) => setState(() => _withTickets = value),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      // One scrolling line, so on phones the chips do not push the list down.
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              key: const Key('todayShowtimesPhase-all'),
              label: Text('All (${matching.length})'),
              selected: _phase == null,
              onSelected: (_) => setState(() => _phase = null),
            ),
            for (final phase in ShowtimePhase.values)
              ChoiceChip(
                key: Key('todayShowtimesPhase-${phase.name}'),
                label: Text('${_phaseLabels[phase]} (${counts[phase]})'),
                selected: _phase == phase,
                onSelected: (_) =>
                    setState(() => _phase = _phase == phase ? null : phase),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        '${visible.length} of ${shows.length} showtimes',
        key: const Key('todayShowtimesCount'),
        style: AppTextStyles.caption,
      ),
      const SizedBox(height: AppSpacing.sm),
      Flexible(
        child: visible.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  shows.isEmpty
                      ? 'There are no showtimes today.'
                      : 'No showtimes match these filters.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: visible.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final show = visible[index];
                  return _ShowtimeRow(
                    showtime: show,
                    phase: showtimePhase(show, _now),
                    title: _title(show),
                    room: _roomName(show),
                    capacity: _rooms[show.roomId]?.totalSeats,
                    stats:
                        _stats[show.id] ??
                        ShowtimeBookingStats(showtimeId: show.id),
                  );
                },
              ),
      ),
    ];
  }
}

class _ShowtimeRow extends StatelessWidget {
  const _ShowtimeRow({
    required this.showtime,
    required this.phase,
    required this.title,
    required this.room,
    required this.capacity,
    required this.stats,
  });

  final Showtime showtime;
  final ShowtimePhase phase;
  final String title;
  final String room;
  final int? capacity;
  final ShowtimeBookingStats stats;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final taken = stats.soldSeats + stats.heldSeats;
    final details = [
      room,
      showtime.format,
      formatVnd(showtime.price),
      if (showtime.status == 'CLOSED') 'Sales closed',
    ].where((part) => part.isNotEmpty).join(' • ');

    return InkWell(
      key: ValueKey('todayShowtime-${showtime.id}'),
      borderRadius: AppRadius.borderRadiusMd,
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.staffRecord('showtimes', showtime.id),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.surfaceSoft.withValues(alpha: 0.6),
          borderRadius: AppRadius.borderRadiusMd,
          border: Border.all(color: palette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatTime(showtime.startTime),
                      style: AppTextStyles.title,
                    ),
                  ),
                  Text(
                    formatTime(showtime.endTime),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusBadge(
                        label: _phaseLabels[phase]!,
                        variant: _phaseBadges[phase]!,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(details, style: AppTextStyles.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      capacity == null
                          ? '$taken seats taken'
                          : '$taken/$capacity seats taken',
                      if (stats.heldSeats > 0)
                        '${stats.heldSeats} awaiting payment',
                      '${stats.checkedInSeats} checked in',
                    ].join(' • '),
                    style: AppTextStyles.caption.copyWith(
                      color: taken > 0 ? palette.primary : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
