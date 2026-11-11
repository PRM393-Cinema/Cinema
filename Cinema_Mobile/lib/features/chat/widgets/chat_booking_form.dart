import 'package:flutter/material.dart';

import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/services/chat_service.dart';

class ChatBookingFormCard extends StatefulWidget {
  const ChatBookingFormCard({
    required this.details,
    required this.onSearch,
    required this.onBack,
    super.key,
  });

  final ChatBookingForm details;
  final ValueChanged<String> onSearch;
  final VoidCallback onBack;

  @override
  State<ChatBookingFormCard> createState() => _ChatBookingFormCardState();
}

class _ChatBookingFormCardState extends State<ChatBookingFormCard> {
  final _form = GlobalKey<FormState>();
  late final _movie = TextEditingController(text: widget.details.movie);
  late final _date = TextEditingController(
    text: widget.details.date?.split('-').reversed.join('/'),
  );
  late final _time = TextEditingController(text: widget.details.time);
  late final _tickets = TextEditingController(
    text: widget.details.tickets?.toString(),
  );

  @override
  void dispose() {
    _movie.dispose();
    _date.dispose();
    _time.dispose();
    _tickets.dispose();
    super.dispose();
  }

  String? _isoDate(String? input) {
    final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$')
        .firstMatch(input?.trim() ?? '');
    if (match == null) return null;
    final day = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final year = int.parse(match[3]!);
    final date = DateTime.utc(year, month, day);
    if (date.day != day || date.month != month || date.year != year) {
      return null;
    }
    final vietnam = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime.utc(vietnam.year, vietnam.month, vietnam.day);
    if (date.isBefore(today) || date.difference(today).inDays > 6) return null;
    return date.toIso8601String().substring(0, 10);
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final date = _isoDate(_date.text);
    widget.onSearch(
      'Tìm suất chiếu để đặt ${_tickets.text.trim()} vé. '
      'Phim hoặc thể loại: ${_movie.text.trim()}. '
      'Ngày: $date, giờ Việt Nam: ${_time.text.trim()}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return CinemaPanel(
      key: const Key('chatBookingForm'),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Thông tin đặt vé',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: widget.onBack,
                  tooltip: 'Quay lại chat',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('chatBookingMovie'),
              controller: _movie,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Phim hoặc thể loại',
                hintText: 'Tên phim, thể loại hoặc Bất kỳ',
                counterText: '',
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Nhập tên phim hoặc thể loại.'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('chatBookingDate'),
              controller: _date,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(labelText: 'Ngày (dd/mm/yyyy)'),
              validator: (value) => _isoDate(value) == null
                  ? 'Chọn ngày trong 7 ngày tới.'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('chatBookingTime'),
              controller: _time,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: 'Giờ dự kiến (HH:mm)',
              ),
              validator: (value) =>
                  RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                      .hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Nhập giờ 24h, ví dụ 19:30.',
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('chatBookingTickets'),
              controller: _tickets,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số vé'),
              validator: (value) =>
                  RegExp(r'^[1-8]$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Nhập số vé từ 1 đến 8.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submit,
              child: const Text('Tìm suất chiếu'),
            ),
          ],
        ),
      ),
    );
  }
}
