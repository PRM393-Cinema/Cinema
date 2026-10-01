import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/cinema_api.dart';
import '../../shared/widgets.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({
    super.key,
    required this.api,
    required this.user,
    required this.onAuthenticate,
    required this.revision,
  });
  final CinemaApi api;
  final Map<String, dynamic>? user;
  final Future<Map<String, dynamic>?> Function() onAuthenticate;
  final int revision;

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  Future<List<Booking>>? _bookings;
  int? _loadedUserId;

  @override
  void didUpdateWidget(covariant TicketsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = (widget.user?['userId'] as num?)?.toInt();
    if (id != _loadedUserId || widget.revision != oldWidget.revision) {
      _loadedUserId = id;
      _bookings = id == null ? null : widget.api.bookingsFor(id);
    }
  }

  void _load() {
    final id = (widget.user?['userId'] as num?)?.toInt();
    _loadedUserId = id;
    if (id != null) setState(() => _bookings = widget.api.bookingsFor(id));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null)
      return SignedOutPanel(
        onTap: widget.onAuthenticate,
        title: 'Vé của bạn ở đây',
        detail: 'Đăng nhập để xem các đơn đặt vé và trạng thái thanh toán.',
      );
    final future = _bookings ??= widget.api.bookingsFor(
      (widget.user!['userId'] as num).toInt(),
    );
    return SafeArea(
      child: RefreshIndicator(
        color: CinemaColors.gold,
        onRefresh: () async {
          _load();
          try {
            await _bookings;
          } catch (_) {}
        },
        child: FutureBuilder<List<Booking>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(
                child: CircularProgressIndicator(color: CinemaColors.gold),
              );
            if (snapshot.hasError)
              return MessageState(
                title: 'Không tải được vé',
                detail: snapshot.error.toString(),
                action: 'Thử lại',
                onAction: _load,
              );
            final bookings = snapshot.data ?? [];
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Vé của tôi',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                if (bookings.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: MessageState(
                      title: 'Chưa có vé nào',
                      detail: 'Chọn phim và suất chiếu để đặt vé đầu tiên.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList.separated(
                      itemCount: bookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) =>
                          _TicketCard(booking: bookings[index]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final status = booking.status.toUpperCase();
    final confirmed =
        status == 'CONFIRMED' || status == 'BOOKED' || status == 'SUCCESS';
    final expired =
        status == 'EXPIRED' ||
        (booking.expiresAt?.isBefore(DateTime.now()) ?? false);
    final cancelled = status == 'CANCELLED' || expired;
    final color = confirmed
        ? CinemaColors.green
        : cancelled
        ? CinemaColors.muted
        : const Color(0xFF9B681B);
    final label = confirmed
        ? 'ĐÃ XÁC NHẬN'
        : cancelled
        ? (expired ? 'HẾT HẠN' : 'ĐÃ HỦY')
        : 'CHỜ THANH TOÁN';
    return Container(
      decoration: BoxDecoration(
        color: CinemaColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CinemaColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.movieTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                StatusTag(text: label, color: color),
              ],
            ),
            const SizedBox(height: 14),
            if (booking.showTime != null)
              MetaLine(
                icon: Icons.schedule_outlined,
                text:
                    '${formatDateLabel(booking.showTime!)} · ${formatTime(booking.showTime!)}',
              ),
            if (booking.seats.isNotEmpty) ...[
              const SizedBox(height: 8),
              MetaLine(
                icon: Icons.event_seat_outlined,
                text: booking.seats.join(', '),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.code,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  formatMoney(booking.amount),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
