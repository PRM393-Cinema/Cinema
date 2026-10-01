import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/cinema_api.dart';
import '../../shared/widgets.dart';
import '../booking/seat_picker_page.dart';

class MovieDetailPage extends StatefulWidget {
  const MovieDetailPage({
    super.key,
    required this.api,
    required this.movie,
    required this.onAuthenticate,
    required this.onBookingCreated,
  });
  final CinemaApi api;
  final Movie movie;
  final Future<Map<String, dynamic>?> Function() onAuthenticate;
  final VoidCallback onBookingCreated;

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  late Future<List<Showtime>> _showtimes;

  @override
  void initState() {
    super.initState();
    _showtimes = widget.api.showtimesFor(widget.movie.id);
  }

  void _retry() =>
      setState(() => _showtimes = widget.api.showtimesFor(widget.movie.id));

  Future<void> _select(Showtime showtime) async {
    if (widget.api.user == null && await widget.onAuthenticate() == null)
      return;
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SeatPickerPage(
          api: widget.api,
          movie: widget.movie,
          showtime: showtime,
          onAuthenticate: widget.onAuthenticate,
          onBookingCreated: widget.onBookingCreated,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: FutureBuilder<List<Showtime>>(
        future: _showtimes,
        builder: (context, snapshot) {
          final shows = (snapshot.data ?? [])
              .where((show) => show.start.isAfter(DateTime.now()))
              .toList();
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: CinemaColors.paper,
                leading: IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                title: Text(
                  widget.movie.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CinemaPoster(
                        url: widget.movie.posterUrl,
                        width: 124,
                        height: 184,
                        radius: 16,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              widget.movie.title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            if (widget.movie.genre.isNotEmpty)
                              MetaLine(
                                icon: Icons.movie_filter_outlined,
                                text: widget.movie.genre,
                              ),
                            if (widget.movie.duration > 0) ...[
                              const SizedBox(height: 9),
                              MetaLine(
                                icon: Icons.schedule_outlined,
                                text: '${widget.movie.duration} phút',
                              ),
                            ],
                            const SizedBox(height: 16),
                            const StatusTag(text: 'ĐANG CHIẾU'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.movie.description.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      widget.movie.description,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: CinemaColors.muted),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: SectionHeading(
                    title: 'Chọn suất chiếu',
                    subtitle: 'Lịch chiếu sắp tới',
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(36),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: CinemaColors.gold,
                      ),
                    ),
                  ),
                )
              else if (snapshot.hasError)
                SliverToBoxAdapter(
                  child: MessageState(
                    title: 'Không tải được lịch chiếu',
                    detail: snapshot.error.toString(),
                    action: 'Thử lại',
                    onAction: _retry,
                  ),
                )
              else if (shows.isEmpty)
                const SliverToBoxAdapter(
                  child: MessageState(
                    title: 'Chưa có suất chiếu',
                    detail: 'Phim này chưa có lịch chiếu sắp tới.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: shows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => _ShowtimeTile(
                      showtime: shows[index],
                      onTap: () => _select(shows[index]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _ShowtimeTile extends StatelessWidget {
  const _ShowtimeTile({required this.showtime, required this.onTap});
  final Showtime showtime;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: CinemaColors.surface,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 74),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CinemaColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: CinemaColors.paper,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    formatTime(showtime.start),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    formatWeekday(showtime.start),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formatDateLabel(showtime.start),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Phòng ${showtime.roomId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              formatMoney(showtime.price),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: CinemaColors.muted),
          ],
        ),
      ),
    ),
  );
}
