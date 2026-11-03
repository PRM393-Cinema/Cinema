import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
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
  final _scroll = ScrollController();
  int _page = 1;
  int _pageSize = 10;
  bool _loading = false;
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
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    final service = widget.service;
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    setState(() {
      _error = null;
      _loading = true;
    });
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
        _page = 1;
        if (!shows.any((show) => show.roomId == _roomId)) _roomId = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _change(VoidCallback update) {
    setState(() {
      update();
      _page = 1;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _openPage(int page) {
    setState(() => _page = page);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _openShow(Showtime show) =>
      Navigator.pushNamed(context, AppRoutes.staffRecord('showtimes', show.id));

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
          maxWidth: 1200,
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
                    onPressed: _loading ? null : _load,
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
              if (_loading && shows != null)
                const LinearProgressIndicator(minHeight: 2),
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
    // shortcut: paginate the loaded day; use server filters/paging for much larger schedules.
    final pages = math.max(1, (visible.length / _pageSize).ceil());
    final page = _page.clamp(1, pages);
    final start = (page - 1) * _pageSize;
    final end = math.min(start + _pageSize, visible.length);
    final rows = visible.sublist(start, end);

    return [
      Flexible(
        child: SingleChildScrollView(
          key: const Key('todayShowtimesBody'),
          controller: _scroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                      onChanged: (_) => _change(() {}),
                    ),
                  ),
                  SizedBox(
                    width: compact ? double.infinity : 240,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Room',
                        isDense: true,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          key: const Key('todayShowtimesRoom'),
                          isExpanded: true,
                          isDense: true,
                          value: _roomId,
                          hint: const Text('All rooms'),
                          items: [
                            const DropdownMenuItem<int?>(
                              child: Text('All rooms'),
                            ),
                            for (final id in roomIds)
                              DropdownMenuItem<int?>(
                                value: id,
                                child: Text(_rooms[id]?.name ?? 'Room #$id'),
                              ),
                          ],
                          onChanged: (value) => _change(() => _roomId = value),
                        ),
                      ),
                    ),
                  ),
                  FilterChip(
                    key: const Key('todayShowtimesWithTickets'),
                    label: const Text('With tickets'),
                    selected: _withTickets,
                    onSelected: (value) => _change(() => _withTickets = value),
                  ),
                  if (_search.text.isNotEmpty ||
                      _roomId != null ||
                      _phase != null ||
                      _withTickets)
                    TextButton(
                      onPressed: () => _change(() {
                        _search.clear();
                        _roomId = null;
                        _phase = null;
                        _withTickets = false;
                      }),
                      child: const Text('Clear filters'),
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
                      onSelected: (_) => _change(() => _phase = null),
                    ),
                    for (final phase in ShowtimePhase.values)
                      ChoiceChip(
                        key: Key('todayShowtimesPhase-${phase.name}'),
                        label: Text(
                          '${_phaseLabels[phase]} (${counts[phase]})',
                        ),
                        selected: _phase == phase,
                        onSelected: (_) => _change(
                          () => _phase = _phase == phase ? null : phase,
                        ),
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
              visible.isEmpty
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
                  : isDesktopLayout(context)
                  ? _table(rows)
                  : Column(
                      children: [
                        for (final show in rows) ...[
                          _ShowtimeRow(
                            showtime: show,
                            phase: showtimePhase(show, _now),
                            title: _title(show),
                            room: _roomName(show),
                            capacity: _rooms[show.roomId]?.totalSeats,
                            stats:
                                _stats[show.id] ??
                                ShowtimeBookingStats(showtimeId: show.id),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
            ],
          ),
        ),
      ),
      Divider(height: AppSpacing.lg, color: AppPalette.of(context).border),
      Wrap(
        key: const Key('todayShowtimesPagination'),
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: [
          Text(
            '${visible.isEmpty ? 0 : start + 1}–$end of ${visible.length}',
            style: AppTextStyles.caption,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Rows', style: AppTextStyles.caption),
              const SizedBox(width: AppSpacing.sm),
              DropdownButton<int>(
                key: const Key('todayShowtimesPageSize'),
                value: _pageSize,
                items: [
                  for (final size in [5, 10, 20])
                    DropdownMenuItem(value: size, child: Text('$size')),
                ],
                onChanged: _loading
                    ? null
                    : (size) {
                        if (size != null) _change(() => _pageSize = size);
                      },
              ),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              IconButton(
                key: const Key('todayShowtimesPrevious'),
                tooltip: 'Previous page',
                onPressed: page > 1 ? () => _openPage(page - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Semantics(
                container: true,
                liveRegion: true,
                label: 'Page $page of $pages',
                child: ExcludeSemantics(
                  child: Text(
                    'Page $page of $pages',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ),
              IconButton(
                key: const Key('todayShowtimesNext'),
                tooltip: 'Next page',
                onPressed: page < pages ? () => _openPage(page + 1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  Widget _table(List<Showtime> rows) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        child: DataTable(
          key: const Key('todayShowtimesTable'),
          showCheckboxColumn: false,
          headingRowHeight: 40,
          dataRowMinHeight: 64,
          dataRowMaxHeight: double.infinity,
          columnSpacing: AppSpacing.md,
          horizontalMargin: AppSpacing.md,
          columns: const [
            DataColumn(label: Text('Time')),
            DataColumn(label: Text('Movie / room')),
            DataColumn(label: Text('Format')),
            DataColumn(label: Text('Price'), numeric: true),
            DataColumn(label: Text('Tickets')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Action')),
          ],
          rows: [for (final show in rows) _dataRow(show)],
        ),
      ),
    ),
  );

  DataRow _dataRow(Showtime show) {
    final phase = showtimePhase(show, _now);
    final stats = _stats[show.id] ?? ShowtimeBookingStats(showtimeId: show.id);
    final taken = stats.soldSeats + stats.heldSeats;
    final capacity = _rooms[show.roomId]?.totalSeats;
    return DataRow(
      onSelectChanged: (_) => _openShow(show),
      cells: [
        DataCell(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatTime(show.startTime),
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(formatTime(show.endTime), style: AppTextStyles.caption),
            ],
          ),
        ),
        DataCell(
          SizedBox(
            width: 220,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: _title(show),
                  child: Text(
                    _title(show),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Tooltip(
                  message: _roomName(show),
                  child: Text(
                    _roomName(show),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(show.format),
              if (show.status == 'CLOSED')
                const Text('Sales closed', style: AppTextStyles.caption),
            ],
          ),
        ),
        DataCell(Text(formatVnd(show.price))),
        DataCell(
          Tooltip(
            message:
                '${stats.soldSeats} sold · ${stats.heldSeats} awaiting payment',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  capacity == null
                      ? '$taken seats taken'
                      : '$taken/$capacity seats taken',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  '${stats.checkedInSeats} checked in',
                  style: AppTextStyles.caption,
                ),
                if (stats.heldSeats > 0)
                  Text(
                    '${stats.heldSeats} awaiting payment',
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
        ),
        DataCell(
          StatusBadge(
            label: _phaseLabels[phase]!,
            variant: _phaseBadges[phase]!,
          ),
        ),
        DataCell(
          TextButton(
            key: ValueKey('todayShowtime-${show.id}'),
            onPressed: () => _openShow(show),
            child: const Text('View seats'),
          ),
        ),
      ],
    );
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
                  Text(title, style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.xs),
                  StatusBadge(
                    label: _phaseLabels[phase]!,
                    variant: _phaseBadges[phase]!,
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
