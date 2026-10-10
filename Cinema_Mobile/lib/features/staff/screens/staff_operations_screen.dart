import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/paged_result.dart';
import '../../../data/models/payment.dart';
import '../../../data/models/room.dart';
import '../../../data/models/showtime.dart';
import '../../../data/services/staff_service.dart';
import '../../admin/widgets/admin_page.dart';
import '../widgets/staff_feedback.dart';

class StaffOperationsScreen extends StatefulWidget {
  const StaffOperationsScreen({required this.service, super.key});
  final StaffService service;
  @override
  State<StaffOperationsScreen> createState() => _StaffOperationsScreenState();
}

class _StaffOperationsScreenState extends State<StaffOperationsScreen> {
  static const sections = [
    'Bookings',
    'Showtimes',
    'Rooms',
    'Payments',
    'Refunds',
  ];
  String _section = sections.first;
  String _status = 'ALL';
  final _lookup = TextEditingController();
  PagedResult<Object>? _result;
  DateTimeRange? _dates;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _lookup.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final start = _dates?.start;
      final end = _dates?.end
          .add(const Duration(days: 1))
          .subtract(const Duration(microseconds: 1));
      final result = switch (_section) {
        'Bookings' => await widget.service.bookings(
          page: page,
          status: _status == 'ALL' ? null : _status,
          start: start,
          end: end,
        ),
        'Showtimes' => await widget.service.showtimes(
          page: page,
          start: start,
          end: end,
        ),
        'Rooms' => await widget.service.rooms(
          page: page,
          keyword: _lookup.text.trim(),
        ),
        'Payments' => await widget.service.payments(page: page),
        _ => await widget.service.refunds(
          page: page,
          status: _status == 'ALL' ? null : _status,
        ),
      };
      if (mounted) setState(() => _result = result);
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) _load();
  }

  Future<void> _pickDates() async {
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _dates,
    );
    if (dates == null || !mounted) return;
    setState(() {
      _dates = dates;
      _status = 'ALL';
    });
    _load();
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Operations',
    selectedIndex: 1,
    staffMode: true,
    child: RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: staffPadding(context),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final section in sections)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(section),
                      selected: _section == section,
                      onSelected: _loading
                          ? null
                          : (_) {
                              setState(() {
                                _section = section;
                                _status = 'ALL';
                                _dates = null;
                                _lookup.clear();
                                _result = null;
                              });
                              _load();
                            },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_section == 'Bookings' || _section == 'Rooms')
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _lookup,
                    label: _section == 'Rooms'
                        ? 'Search room name'
                        : 'Booking ID',
                    keyboardType: _section == 'Rooms'
                        ? TextInputType.text
                        : TextInputType.number,
                  ),
                ),
                IconButton(
                  tooltip: _section == 'Rooms'
                      ? 'Search rooms'
                      : 'Open booking',
                  icon: const Icon(Icons.search),
                  onPressed: _loading
                      ? null
                      : () {
                          if (_section == 'Rooms') {
                            _load();
                            return;
                          }
                          final id = int.tryParse(_lookup.text.trim());
                          if (id == null || id <= 0) {
                            setState(
                              () => _error = 'Enter a valid booking ID.',
                            );
                            return;
                          }
                          _open(AppRoutes.staffRecord('bookings', id));
                        },
                ),
              ],
            ),
          if (_section == 'Bookings' || _section == 'Refunds')
            DropdownButton<String>(
              value: _status,
              isExpanded: true,
              items: [
                for (final status
                    in _section == 'Bookings'
                        ? [
                            'ALL',
                            'PENDING',
                            'CONFIRMED',
                            'CANCELLED',
                            'EXPIRED',
                          ]
                        : ['ALL', 'PENDING', 'COMPLETED'])
                  DropdownMenuItem(value: status, child: Text(status)),
              ],
              onChanged: _loading
                  ? null
                  : (value) {
                      setState(() {
                        _status = value!;
                        _dates = null;
                      });
                      _load();
                    },
            ),
          if (_section == 'Bookings' || _section == 'Showtimes')
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: _dates == null
                        ? 'Filter dates'
                        : '${formatShortDate(_dates!.start)} – ${formatShortDate(_dates!.end)}',
                    leadingIcon: Icons.date_range_outlined,
                    onPressed: _loading ? null : _pickDates,
                  ),
                ),
                if (_dates != null)
                  IconButton(
                    tooltip: 'Clear date filter',
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() => _dates = null);
                            _load();
                          },
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
          if (_section == 'Bookings' || _section == 'Showtimes')
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: AppButton(
                label: _section == 'Bookings'
                    ? 'Book for a customer'
                    : 'Create showtime',
                useGradient: true,
                leadingIcon: Icons.add,
                onPressed: _loading
                    ? null
                    : () => _open(
                        _section == 'Bookings'
                            ? AppRoutes.staffCreateBooking
                            : AppRoutes.staffCreateShowtime,
                      ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const LoadingState(message: 'Loading operations...')
          else if (_error != null)
            ErrorState(
              title: 'Unable to load',
              message: _error!,
              onRetry: () => _load(),
            )
          else if (_result != null) ...[
            Text(
              '${_result!.totalCount} results',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_result!.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'No matching records.',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            for (final item in _result!.items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: CinemaPanel(
                  surfaceOpacity: 0.8,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_title(item), style: AppTextStyles.title),
                    subtitle: Text(
                      _subtitle(item),
                      style: AppTextStyles.bodySmall,
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.primary,
                    ),
                    onTap: () => _open(_route(item)),
                  ),
                ),
              ),
            if (_result!.totalPages > 1)
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Previous',
                      onPressed: _result!.pageNumber > 1
                          ? () => _load(page: _result!.pageNumber - 1)
                          : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      '${_result!.pageNumber}/${_result!.totalPages}',
                      style: AppTextStyles.caption,
                    ),
                  ),
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Next',
                      onPressed: _result!.pageNumber < _result!.totalPages
                          ? () => _load(page: _result!.pageNumber + 1)
                          : null,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    ),
  );
  String _title(Object item) => switch (item) {
    Booking b => b.bookingCode,
    Showtime s => 'Showtime #${s.id}',
    Room r => r.name,
    PaymentInfo p => p.paymentCode,
    Refund r => r.refundCode,
    _ => '',
  };
  String _subtitle(Object item) => switch (item) {
    Booking b =>
      '${b.movieTitle ?? 'Movie'}\n${b.status.name.toUpperCase()} · ${formatVnd(b.totalAmount)}',
    Showtime s =>
      '${s.roomLabel} · ${formatDateTime(s.startTime)}\n${s.status} · ${formatVnd(s.price)}',
    Room r => '${r.totalSeats} seats',
    PaymentInfo p =>
      'Booking #${p.bookingId}\n${p.status.name} · ${formatVnd(p.amount)}',
    Refund r => '${r.status} · ${formatVnd(r.amount)}',
    _ => '',
  };
  String _route(Object item) => switch (item) {
    Booking b => AppRoutes.staffRecord('bookings', b.id),
    Showtime s => AppRoutes.staffRecord('showtimes', s.id),
    Room r => AppRoutes.staffRecord('rooms', r.id),
    PaymentInfo p => AppRoutes.staffRecord('payments', p.id),
    Refund r => AppRoutes.staffRecord('refunds', r.id),
    _ => AppRoutes.staffOperations,
  };
}
