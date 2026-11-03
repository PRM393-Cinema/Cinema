import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/paged_result.dart';
import '../../../data/models/payment.dart';
import '../../../data/models/room.dart';
import '../../../data/models/showtime.dart';
import '../../../data/services/staff_service.dart';
import '../../../core/widgets/responsive_columns.dart';
import '../../admin/widgets/admin_page.dart';
import '../widgets/staff_feedback.dart';
import '../widgets/operations_date_filter_dialog.dart';

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
  // The route's MediaQuery excludes the sidebar; use the window breakpoint.
  bool get _desktop {
    final view = View.of(context);
    return view.physicalSize.width / MediaQuery.of(context).devicePixelRatio >=
        desktopBreakpoint;
  }

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
    final dates = await showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OperationsDateFilterDialog(initialRange: _dates),
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
    section: AdminSection.operations,
    child: RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final section in sections)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: Semantics(
                      selected: _section == section,
                      child: TextButton(
                        key: ValueKey('operationsTab-$section'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          foregroundColor: _section == section
                              ? AppPalette.of(context).primary
                              : AppPalette.of(context).textSecondary,
                          backgroundColor: _section == section
                              ? AppPalette.of(context).primary
                                    .withValues(alpha: 0.08)
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          textStyle: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _loading
                            ? null
                            : () {
                                setState(() {
                                  _section = section;
                                  _status = 'ALL';
                                  _dates = null;
                                  _lookup.clear();
                                  _result = null;
                                });
                                _load();
                              },
                        child: Text(section),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _toolbar(),
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
            if (_result!.items.isNotEmpty && _desktop)
              _table()
            else
              CardColumns(
                runSpacing: 0,
                children: [
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
                          trailing: Icon(
                            Icons.chevron_right,
                            color: AppPalette.of(context).primary,
                          ),
                          onTap: () => _open(_route(item)),
                        ),
                      ),
                    ),
                ],
              ),
            if (_result!.totalPages > 1) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  TextButton.icon(
                    key: const Key('operationsPrevious'),
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    label: const Text('Previous'),
                    onPressed: !_loading && _result!.pageNumber > 1
                        ? () => _load(page: _result!.pageNumber - 1)
                        : null,
                  ),
                  Text(
                    'Page ${_result!.pageNumber} of ${_result!.totalPages}',
                    style: AppTextStyles.caption,
                  ),
                  TextButton.icon(
                    key: const Key('operationsNext'),
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    iconAlignment: IconAlignment.end,
                    label: const Text('Next'),
                    onPressed:
                        !_loading && _result!.pageNumber < _result!.totalPages
                        ? () => _load(page: _result!.pageNumber + 1)
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    ),
  );

  Widget _toolbar() => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = _desktop;
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final hasLookup = _section == 'Bookings' || _section == 'Rooms';
      final hasStatus = _section == 'Bookings' || _section == 'Refunds';
      final hasDates = _section == 'Bookings' || _section == 'Showtimes';
      final actionWidth = (_section == 'Bookings' ? 152 : 184) * scale;
      final otherWidth =
          (hasStatus ? 180 * scale + 12 : 0) +
          (hasDates ? 180 * scale + actionWidth + 24 : 0);
      final lookupWidth = (constraints.maxWidth - otherWidth).clamp(
        220 * scale,
        double.infinity,
      );
      final controls = <(double, Widget)>[
        if (hasLookup)
          (
            lookupWidth,
            AppTextField(
              key: const Key('operationsLookup'),
              controller: _lookup,
              label: _section == 'Rooms' ? 'Search room name' : 'Booking ID',
              keyboardType: _section == 'Rooms'
                  ? TextInputType.text
                  : TextInputType.number,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: IconButton(
                tooltip: _section == 'Rooms' ? 'Search rooms' : 'Open booking',
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                onPressed: _loading
                    ? null
                    : () {
                        if (_section == 'Rooms') {
                          _load();
                          return;
                        }
                        final id = int.tryParse(_lookup.text.trim());
                        if (id == null || id <= 0) {
                          setState(() => _error = 'Enter a valid booking ID.');
                          return;
                        }
                        _open(AppRoutes.staffRecord('bookings', id));
                      },
              ),
            ),
          ),
        if (hasStatus)
          (
            180 * scale,
            DropdownButtonFormField<String>(
              key: ValueKey('operationsStatus-$_section-$_status'),
              initialValue: _status,
              isExpanded: true,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppPalette.of(context).textPrimary,
              ),
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final status
                    in _section == 'Bookings'
                        ? [
                            'ALL',
                            'PENDING',
                            'CONFIRMED',
                            'REFUND_PENDING',
                            'CANCELLED',
                            'EXPIRED',
                          ]
                        : ['ALL', 'PENDING', 'COMPLETED', 'REJECTED'])
                  DropdownMenuItem(
                    value: status,
                    child: Text(
                      status == 'ALL' ? 'All statuses' : _statusLabel(status),
                    ),
                  ),
              ],
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _status = value;
                        _dates = null;
                      });
                      _load();
                    },
            ),
          ),
        if (hasDates) ...[
          (
            180 * scale,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('operationsDates'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      textStyle: AppTextStyles.bodySmall,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    label: Text(
                      _dates == null
                          ? 'Filter dates'
                          : '${formatShortDate(_dates!.start)} – ${formatShortDate(_dates!.end)}',
                    ),
                    icon: const Icon(Icons.date_range_outlined, size: 18),
                    onPressed: _loading ? null : _pickDates,
                  ),
                ),
                if (_dates != null)
                  IconButton(
                    tooltip: 'Clear date filter',
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() => _dates = null);
                            _load();
                          },
                  ),
              ],
            ),
          ),
          (
            actionWidth,
            FilledButton.icon(
              key: const Key('operationsCreate'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                _section == 'Bookings' ? 'Sell tickets' : 'Create showtime',
              ),
              onPressed: _loading
                  ? null
                  : () => _open(
                      _section == 'Bookings'
                          ? AppRoutes.staffCreateBooking
                          : AppRoutes.staffCreateShowtime,
                    ),
            ),
          ),
        ],
      ];
      return Wrap(
        key: const Key('operationsToolbar'),
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (width, control) in controls)
            SizedBox(
              width: desktop
                  ? width.clamp(0, constraints.maxWidth)
                  : constraints.maxWidth,
              child: control,
            ),
        ],
      );
    },
  );

  Widget _table() {
    final colors = AppPalette.of(context);
    final columns = switch (_section) {
      'Bookings' => [
        ('Booking ID', 3.0),
        ('Movie', 2.2),
        ('Date', 1.6),
        ('Amount', 1.5),
        ('Status', 1.7),
        ('Actions', 1.0),
      ],
      'Showtimes' => [
        ('Showtime ID', 1.5),
        ('Movie', 1.3),
        ('Room', 1.7),
        ('Date', 2.0),
        ('Price', 1.5),
        ('Status', 1.5),
        ('Actions', 1.0),
      ],
      'Rooms' => [
        ('Room ID', 1.0),
        ('Name', 3.0),
        ('Seats', 1.0),
        ('Actions', 1.0),
      ],
      'Payments' => [
        ('Payment ID', 3.0),
        ('Booking', 1.0),
        ('Date', 1.6),
        ('Amount', 1.5),
        ('Method', 1.2),
        ('Status', 1.7),
        ('Actions', 1.0),
      ],
      _ => [
        ('Refund ID', 3.0),
        ('Payment', 1.0),
        ('Date', 1.6),
        ('Amount', 1.5),
        ('Status', 1.7),
        ('Actions', 1.0),
      ],
    };
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) => Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth.clamp(
              (_section == 'Rooms' ? 640 : 1020) * scale,
              double.infinity,
            ),
            child: SelectionArea(
              child: DataTable(
                key: const Key('operationsTable'),
                horizontalMargin: AppSpacing.md,
                columnSpacing: AppSpacing.md,
                headingRowHeight: 40 * scale,
                dataRowMinHeight: 56 * scale,
                dataRowMaxHeight: double.infinity,
                headingRowColor: WidgetStatePropertyAll(colors.surfaceSoft),
                headingTextStyle: AppTextStyles.caption.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                dataTextStyle: AppTextStyles.bodySmall.copyWith(
                  color: colors.textPrimary,
                ),
                border: TableBorder(
                  horizontalInside: BorderSide(color: colors.border),
                ),
                columns: [
                  for (final (label, width) in columns)
                    DataColumn(
                      label: Expanded(
                        child: Text(
                          label,
                          textAlign:
                              const ['Amount', 'Price', 'Seats'].contains(label)
                              ? TextAlign.end
                              : TextAlign.start,
                        ),
                      ),
                      numeric: const [
                        'Amount',
                        'Price',
                        'Seats',
                      ].contains(label),
                      columnWidth: FlexColumnWidth(width),
                    ),
                ],
                rows: [
                  for (final item in _result!.items)
                    DataRow(
                      cells: [
                        for (final cell in _cells(item)) DataCell(cell),
                        DataCell(
                          TextButton(
                            onPressed: () => _open(_route(item)),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              textStyle: AppTextStyles.bodySmall,
                            ),
                            child: const Text('View'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _cells(Object item) => switch (item) {
    Booking b => [
      _identifier(b.bookingCode, b.id),
      Text(b.movieTitle ?? 'Movie'),
      _date(b.createdAt),
      _amount(b.totalAmount),
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge(b.status.name),
          if (b.isCheckedIn)
            const Text('Checked in', style: AppTextStyles.caption),
        ],
      ),
    ],
    Showtime s => [
      Text('#${s.id}'),
      Text('Movie #${s.movieId}'),
      Text(s.roomLabel),
      _date(s.startTime),
      _amount(s.priceOf('NORMAL')),
      _badge(s.status),
    ],
    Room r => [Text('#${r.id}'), Text(r.name), Text('${r.totalSeats}')],
    PaymentInfo p => [
      _identifier(p.paymentCode, p.id),
      Text('#${p.bookingId}'),
      _date(p.createdAt),
      _amount(p.amount),
      Text(p.method?.trim().isNotEmpty == true ? p.method! : 'Not specified'),
      _badge(p.status.name),
    ],
    Refund r => [
      _identifier(r.refundCode, r.id),
      Text('#${r.paymentId}'),
      _date(r.createdAt),
      _amount(r.amount),
      _badge(r.status),
    ],
    _ => [],
  };

  Widget _identifier(String code, int id) => Tooltip(
    message: '$code · ID $id',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          code,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(
          'ID $id',
          style: AppTextStyles.caption.copyWith(
            color: AppPalette.of(context).textSecondary,
          ),
        ),
      ],
    ),
  );
  Widget _date(DateTime date) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(formatDate(date)),
      Text(
        formatTime(date),
        style: AppTextStyles.caption.copyWith(
          color: AppPalette.of(context).textSecondary,
        ),
      ),
    ],
  );
  Widget _amount(double amount) => Text(
    formatVnd(amount),
    style: const TextStyle(
      fontWeight: FontWeight.w600,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );
  String _statusLabel(String status) => switch (status.toUpperCase()) {
    'REFUNDPENDING' || 'REFUND_PENDING' => 'Refund pending',
    'SUCCESS' => 'Paid',
    _ =>
      status.isEmpty
          ? 'Unknown'
          : status[0].toUpperCase() + status.substring(1).toLowerCase(),
  };
  Widget _badge(String status) => StatusBadge(
    label: _statusLabel(status),
    variant: switch (status.toUpperCase()) {
      'CONFIRMED' ||
      'SUCCESS' ||
      'COMPLETED' ||
      'OPEN' => StatusBadgeVariant.success,
      'PENDING' ||
      'REFUND_PENDING' ||
      'REFUNDPENDING' => StatusBadgeVariant.warning,
      'CANCELLED' || 'FAILED' || 'REJECTED' => StatusBadgeVariant.error,
      _ => StatusBadgeVariant.neutral,
    },
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
      '${b.movieTitle ?? 'Movie'}\n${b.status.name.toUpperCase()}'
          '${b.isCheckedIn ? ' · CHECKED IN' : ''} · ${formatVnd(b.totalAmount)}',
    Showtime s =>
      '${s.roomLabel} · ${formatDateTime(s.startTime)}\n${s.status} · ${formatVnd(s.priceOf('NORMAL'))}',
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
