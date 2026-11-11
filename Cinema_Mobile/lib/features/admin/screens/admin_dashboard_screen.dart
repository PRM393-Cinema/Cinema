import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/auth_response.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/staff_service.dart';
import '../../staff/widgets/today_at_cinema.dart';
import '../widgets/admin_layout.dart';
import '../widgets/admin_page.dart';
import '../widgets/revenue_chart.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    required this.repository,
    required this.service,
    super.key,
  });
  final AuthRepository repository;
  final StaffService service;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _revenueChart = GlobalKey();
  int _period = 0;
  DateTimeRange? _reportDates;
  bool _loadingBusiness = false;
  List<(String, int, IconData)>? _counts;
  // Bookings, ticket sales, movies and showtimes; null when they could not be
  // loaded (the account figures still show).
  List<(String, Object, IconData)>? _business;
  List<(DateTime, double)>? _dailyRevenue;
  int _refreshes = 0;
  List<AuthUser> _users = [];
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _refreshes++;
    });
    final business = _loadBusiness();
    try {
      final pages = await Future.wait([
        widget.repository.users(),
        widget.repository.users(enabled: true),
        widget.repository.users(enabled: false),
      ]);
      final roles = await widget.repository.roles();
      if (!mounted) return;
      setState(() {
        _counts = [
          ('Total accounts', pages[0].totalCount, Icons.people_outline),
          ('Active', pages[1].totalCount, Icons.verified_user_outlined),
          ('Locked', pages[2].totalCount, Icons.lock_outline),
          ('Roles', roles.length, Icons.admin_panel_settings_outlined),
        ];
        _users = pages[0].items.take(5).toList();
      });
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Unable to load dashboard. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    await business;
  }

  String get _periodLabel => switch (_period) {
    1 => 'Today',
    7 => 'Last 7 days',
    _ => 'This month',
  };

  String get _bookingLabel => 'Bookings ${_periodLabel.toLowerCase()}';
  String get _revenueLabel => 'Revenue ${_periodLabel.toLowerCase()}';
  String get _showtimeLabel => 'Showtimes ${_periodLabel.toLowerCase()}';

  Future<void> _loadBusiness() async {
    if (_loadingBusiness) return;
    final today = DateUtils.dateOnly(DateTime.now());
    final start = _period == 0
        ? DateTime(today.year, today.month)
        : DateUtils.addDaysToDate(today, 1 - _period);
    final dates = DateTimeRange(start: start, end: today);
    final end = DateUtils.addDaysToDate(
      today,
      1,
    ).subtract(const Duration(microseconds: 1));
    setState(() => _loadingBusiness = true);
    try {
      final bookings = await widget.service.bookings(start: start, end: end);
      final sales = await widget.service.paymentSummary(start, end);
      final daily = sales.dailyRevenue;
      final movies = await widget.service.catalogMovies(
        status: 'ACTIVE',
        size: 1,
      );
      final shows = await widget.service.showtimes(start: start, end: end);
      if (!mounted) return;
      setState(() {
        _reportDates = dates;
        _business = [
          (
            _bookingLabel,
            bookings.totalCount,
            Icons.confirmation_number_outlined,
          ),
          (_revenueLabel, formatVnd(sales.revenue), Icons.payments_outlined),
          ('Movies showing', movies.totalCount, Icons.movie_outlined),
          (_showtimeLabel, shows.totalCount, Icons.event_outlined),
        ];
        _dailyRevenue = daily == null
            ? null
            : [
                for (
                  var date = start;
                  !date.isAfter(today);
                  date = DateUtils.addDaysToDate(date, 1)
                )
                  (
                    date,
                    daily
                        .where((row) => DateUtils.isSameDay(row.$1, date))
                        .fold(0.0, (sum, row) => sum + row.$2),
                  ),
              ];
      });
    } on Object {
      if (mounted) {
        setState(() {
          _business = null;
          _dailyRevenue = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingBusiness = false);
    }
  }

  void _openOperations(String section) {
    Navigator.pushNamed(
      context,
      AppRoutes.staffOperations,
      arguments: (section: section, dates: _reportDates!),
    );
  }

  Future<void> _openUser(AuthUser user) async {
    await Navigator.pushNamed(context, AppRoutes.adminUser(user.userId));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Dashboard',
    section: AdminSection.dashboard,
    child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: pagePadding(
          context,
          AppSpacing.lg,
        ).copyWith(bottom: 112 + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          TodayAtCinema(service: widget.service, refresh: _refreshes),
          const SizedBox(height: AppSpacing.xl),
          const Text('Cinema overview', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (value, label) in [
                (1, 'Today'),
                (7, 'Last 7 days'),
                (0, 'This month'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _period == value,
                  onSelected: _loadingBusiness
                      ? null
                      : (selected) {
                          if (!selected) return;
                          setState(() => _period = value);
                          _loadBusiness();
                        },
                ),
            ],
          ),
          if (_loadingBusiness)
            const LoadingState(message: 'Loading cinema figures...')
          else ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Bookings, revenue and showtimes for the selected period. Movies showing reflects the current catalogue.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_business case final business?)
              StatTiles(
                key: const Key('businessStats'),
                tiles: business,
                compact: true,
                actions: {
                  _bookingLabel: () => _openOperations('Bookings'),
                  _showtimeLabel: () => _openOperations('Showtimes'),
                  'Movies showing': () =>
                      Navigator.pushNamed(context, AppRoutes.adminMovies),
                  if (_dailyRevenue != null)
                    _revenueLabel: () {
                      final chart = _revenueChart.currentContext;
                      if (chart != null) Scrollable.ensureVisible(chart);
                    },
                },
              )
            else
              const Text(
                'Booking and sales figures could not be loaded. Pull to '
                'refresh.',
                style: AppTextStyles.bodySmall,
              ),
            const SizedBox(height: AppSpacing.xl),
            if (_business != null) ...[
              if (_dailyRevenue case final daily?)
                RevenueChart(key: _revenueChart, days: daily)
              else
                const Text(
                  'Daily revenue is unavailable. Refresh after updating the server.',
                  style: AppTextStyles.caption,
                ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ],
          const Text('Account overview', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Manage access and keep your cinema team organized.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const LoadingState(message: 'Loading dashboard...')
          else if (_error != null)
            ErrorState(
              title: 'Unable to load dashboard',
              message: _error!,
              onRetry: _load,
            )
          else if (_counts != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final chart = _AccountStatusChart(
                  total: _counts![0].$2,
                  active: _counts![1].$2,
                  locked: _counts![2].$2,
                );
                if (constraints.maxWidth < desktopBreakpoint) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StatTiles(tiles: _counts!, compact: true),
                      const SizedBox(height: AppSpacing.md),
                      chart,
                    ],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        key: const Key('accountStatsGrid'),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var row = 0; row < 2; row++) ...[
                              if (row != 0)
                                const SizedBox(height: AppSpacing.md),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: StatTile(
                                        tile: _counts![row * 2],
                                        compact: true,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: StatTile(
                                        tile: _counts![row * 2 + 1],
                                        compact: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: chart),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Accounts at a glance',
                    style: AppTextStyles.title,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await Navigator.pushNamed(context, AppRoutes.adminUsers);
                    if (mounted) _load();
                  },
                  child: const Text('View all accounts'),
                ),
              ],
            ),
            Text(
              'Preview of ${_users.length} accounts · open an account to manage access.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_users.isEmpty)
              const Text('No accounts found.', style: AppTextStyles.bodySmall),
            if (_users.isNotEmpty && isDesktopLayout(context))
              CinemaPanel(
                key: const Key('dashboardAccountsTable'),
                padding: EdgeInsets.zero,
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 72,
                        columnSpacing: AppSpacing.lg,
                        horizontalMargin: AppSpacing.lg,
                        columns: const [
                          DataColumn(label: Text('Account')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Roles')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: [
                          for (final user in _users)
                            DataRow(
                              cells: [
                                DataCell(Text(user.displayName)),
                                DataCell(Text(user.email)),
                                DataCell(
                                  Text(
                                    user.roles
                                        .map(
                                          (role) => role
                                              .replaceFirst('ROLE_', '')
                                              .toLowerCase(),
                                        )
                                        .join(', '),
                                  ),
                                ),
                                DataCell(
                                  StatusBadge(
                                    label: user.enabled ? 'Active' : 'Locked',
                                    variant: user.enabled
                                        ? StatusBadgeVariant.success
                                        : StatusBadgeVariant.error,
                                  ),
                                ),
                                DataCell(
                                  TextButton(
                                    onPressed: () => _openUser(user),
                                    child: const Text('View account'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else ...[
              for (final user in _users)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: CinemaPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        user.enabled
                            ? Icons.person_outline
                            : Icons.person_off_outlined,
                        color: user.enabled
                            ? AppPalette.of(context).primary
                            : AppPalette.of(context).error,
                      ),
                      title: Text(
                        user.displayName,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        user.email,
                        style: AppTextStyles.bodySmall,
                      ),
                      trailing: StatusBadge(
                        label: user.enabled ? 'Active' : 'Locked',
                        variant: user.enabled
                            ? StatusBadgeVariant.success
                            : StatusBadgeVariant.error,
                      ),
                      onTap: () => _openUser(user),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    ),
  );
}

class _AccountStatusChart extends StatelessWidget {
  const _AccountStatusChart({
    required this.total,
    required this.active,
    required this.locked,
  });
  final int total;
  final int active;
  final int locked;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final ratio = total == 0 ? 0.0 : (active / total).clamp(0.0, 1.0);
    return CinemaPanel(
      key: const Key('accountStatusChart'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account status', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                container: true,
                label: 'Active accounts: $active of $total',
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: ratio,
                          strokeWidth: 10,
                          color: colors.success,
                          backgroundColor: total == 0
                              ? colors.border
                              : colors.error.withValues(alpha: 0.3),
                        ),
                        Center(
                          child: Text(
                            total == 0 ? '—' : '${(ratio * 100).round()}%',
                            style: AppTextStyles.heading2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge(
                    label: 'Active · $active',
                    variant: StatusBadgeVariant.success,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  StatusBadge(
                    label: 'Locked · $locked',
                    variant: StatusBadgeVariant.error,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    total == 0
                        ? 'No accounts yet.'
                        : '$total accounts in total',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
