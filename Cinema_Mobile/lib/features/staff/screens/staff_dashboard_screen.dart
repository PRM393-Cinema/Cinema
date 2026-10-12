import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/booking.dart';
import '../../../data/services/staff_service.dart';
import '../../admin/widgets/admin_page.dart';
import '../widgets/staff_feedback.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({required this.service, super.key});
  final StaffService service;
  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  List<(String, int, IconData)>? _counts;
  List<Booking> _pending = [];
  bool _loading = false;
  String? _error;
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
    });
    try {
      final today = DateUtils.dateOnly(DateTime.now());
      final end = today
          .add(const Duration(days: 1))
          .subtract(const Duration(microseconds: 1));
      final pending = await widget.service.bookings(status: 'PENDING');
      final bookings = await widget.service.bookings(start: today, end: end);
      final refunds = await widget.service.refunds(status: 'PENDING');
      final shows = await widget.service.showtimes(start: today, end: end);
      if (!mounted) return;
      setState(() {
        _counts = [
          (
            'Bookings today',
            bookings.totalCount,
            Icons.confirmation_number_outlined,
          ),
          ('Pending bookings', pending.totalCount, Icons.schedule),
          ('Pending refunds', refunds.totalCount, Icons.currency_exchange),
          ('Showtimes today', shows.totalCount, Icons.movie_outlined),
        ];
        _pending = pending.items.take(5).toList();
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Staff dashboard',
    selectedIndex: 0,
    staffMode: true,
    child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: staffPadding(context),
        children: [
          const Text('Your cinema shift', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Bookings, showtimes and refund requests in one workspace.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_loading)
            const LoadingState(message: 'Loading shift overview...')
          else if (_error != null)
            ErrorState(
              title: 'Unable to load dashboard',
              message: _error!,
              onRetry: _load,
            )
          else if (_counts != null) ...[
            LayoutBuilder(
              builder: (_, constraints) => Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final (label, count, icon) in _counts!)
                    SizedBox(
                      width: (constraints.maxWidth - AppSpacing.md) / 2,
                      child: CinemaPanel(
                        surfaceOpacity: 0.8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, color: AppColors.primary),
                            const SizedBox(height: AppSpacing.md),
                            Text('$count', style: AppTextStyles.display),
                            const SizedBox(height: AppSpacing.xs),
                            Text(label, style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('Pending bookings', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            if (_pending.isEmpty)
              const Text(
                'No pending bookings.',
                style: AppTextStyles.bodySmall,
              ),
            for (final booking in _pending)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: CinemaPanel(
                  surfaceOpacity: 0.8,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      booking.bookingCode,
                      style: AppTextStyles.title,
                    ),
                    subtitle: Text(
                      booking.movieTitle ?? 'Movie',
                      style: AppTextStyles.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.pushNamed(
                        context,
                        AppRoutes.staffRecord('bookings', booking.id),
                      );
                      if (mounted) _load();
                    },
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
