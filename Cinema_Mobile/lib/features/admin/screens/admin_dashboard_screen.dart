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
import '../../../data/models/auth_response.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/staff_service.dart';
import '../../../core/widgets/responsive_columns.dart';
import '../../staff/widgets/today_at_cinema.dart';
import '../widgets/admin_layout.dart';
import '../widgets/admin_page.dart';

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
  List<(String, int, IconData)>? _counts;
  // Bookings, ticket sales, movies and showtimes; null when they could not be
  // loaded (the account figures still show).
  List<(String, Object, IconData)>? _business;
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
    // The two halves load on their own: one failing keeps the other.
    final business = await _loadBusiness();
    if (mounted) setState(() => _business = business);
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
  }

  // This month so far, and today's showtimes.
  Future<List<(String, Object, IconData)>?> _loadBusiness() async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final today = DateUtils.dateOnly(now);
    final endOfToday = today
        .add(const Duration(days: 1))
        .subtract(const Duration(microseconds: 1));
    try {
      final bookings = await widget.service.bookings(start: month, end: now);
      final sales = await widget.service.paymentSummary(month, now);
      final movies = await widget.service.catalogMovies(
        status: 'ACTIVE',
        size: 1,
      );
      final shows = await widget.service.showtimes(
        start: today,
        end: endOfToday,
      );
      return [
        (
          'Bookings this month',
          bookings.totalCount,
          Icons.confirmation_number_outlined,
        ),
        (
          'Revenue this month',
          formatVnd(sales.revenue),
          Icons.payments_outlined,
        ),
        ('Movies showing', movies.totalCount, Icons.movie_outlined),
        ('Showtimes today', shows.totalCount, Icons.event_outlined),
      ];
    } on Object {
      return null;
    }
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
          if (!_loading) ...[
            const Text('This month', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Bookings and ticket sales since the 1st, movies on show and '
              'today’s showtimes.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_business case final business?)
              StatTiles(key: const Key('businessStats'), tiles: business)
            else
              const Text(
                'Booking and sales figures could not be loaded. Pull to '
                'refresh.',
                style: AppTextStyles.bodySmall,
              ),
            const SizedBox(height: AppSpacing.xxl),
          ],
          const Text('Account overview', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Manage access and keep your cinema team organized.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_loading)
            const LoadingState(message: 'Loading dashboard...')
          else if (_error != null)
            ErrorState(
              title: 'Unable to load dashboard',
              message: _error!,
              onRetry: _load,
            )
          else if (_counts != null) ...[
            StatTiles(tiles: _counts!),
            const SizedBox(height: AppSpacing.xl),
            const Text('Accounts at a glance', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            if (_users.isEmpty)
              const Text('No accounts found.', style: AppTextStyles.bodySmall),
            CardColumns(
              runSpacing: 0,
              children: [
                for (final user in _users)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: CinemaPanel(
                      surfaceOpacity: 0.8,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          user.enabled
                              ? Icons.person_outline
                              : Icons.person_off_outlined,
                          color: user.enabled
                              ? AppColors.primary
                              : AppColors.error,
                        ),
                        title: Text(
                          user.displayName,
                          style: AppTextStyles.title,
                        ),
                        subtitle: Text(
                          user.email,
                          style: AppTextStyles.bodySmall,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            AppRoutes.adminUser(user.userId),
                          );
                          if (mounted) _load();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
