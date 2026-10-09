import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/booking.dart';
import '../../../data/repositories/booking_repository.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({required this.bookingRepository, super.key});

  final BookingRepository bookingRepository;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<Booking> _bookings = const [];
  bool _isLoading = true;
  bool _hasStarted = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStarted) {
      _hasStarted = true;
      _loadBookings();
    }
  }

  Future<void> _loadBookings() async {
    final userId = SessionProvider.of(context).user?.userId;
    if (userId == null) {
      _showError('Please sign in to see your bookings.');
      return;
    }

    setState(() {
      _isLoading = _bookings.isEmpty;
      _errorMessage = null;
    });

    try {
      final bookings = await widget.bookingRepository.getMyBookings(userId);
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _showError(error.message);
    } on FormatException {
      _showError('The server returned an invalid response.');
    } on Object {
      _showError('Something went wrong. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  Future<void> _openBooking(Booking booking) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.bookingDetail(booking.id),
      arguments: booking,
    );
    // The booking may have been paid or cancelled from the detail screen.
    if (mounted) {
      await _loadBookings();
    }
  }

  // Upcoming bookings stay in Active; finished, cancelled and expired ones
  // move to History.
  bool _isActive(Booking booking, DateTime now) {
    return switch (booking.status) {
      BookingStatus.pending => !booking.isHoldExpired(now),
      BookingStatus.confirmed =>
        booking.showTime == null || booking.showTime!.isAfter(now),
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final activeBookings = _bookings.where((b) => _isActive(b, now)).toList();
    final historyBookings = _bookings.where((b) => !_isActive(b, now)).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: const Text('My Bookings'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'History'),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
          ),
        ),
        body: CinemaBackground(
          child: _buildBody(activeBookings, historyBookings),
        ),
        bottomNavigationBar: const CinemaNavigationBar(selectedIndex: 1),
      ),
    );
  }

  Widget _buildBody(List<Booking> active, List<Booking> history) {
    if (_isLoading) {
      return const LoadingState(message: 'Loading bookings...');
    }

    if (_errorMessage != null && _bookings.isEmpty) {
      return ErrorState(
        title: 'Unable to load bookings',
        message: _errorMessage!,
        onRetry: _loadBookings,
      );
    }

    return TabBarView(
      children: [
        _BookingList(
          bookings: active,
          onRefresh: _loadBookings,
          onTap: _openBooking,
        ),
        _BookingList(
          bookings: history,
          onRefresh: _loadBookings,
          onTap: _openBooking,
        ),
      ],
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({
    required this.bookings,
    required this.onRefresh,
    required this.onTap,
  });

  final List<Booking> bookings;
  final Future<void> Function() onRefresh;
  final ValueChanged<Booking> onTap;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: bookings.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: AppSpacing.xxxl * 2),
                Center(
                  child: Text(
                    'No bookings found.',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: centeredPadding(context, AppSpacing.md).copyWith(
                bottom: AppSpacing.md + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: bookings.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final booking = bookings[index];
                return _BookingCard(
                  booking: booking,
                  onTap: () => onTap(booking),
                );
              },
            ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String showTimeStr = booking.showTime != null
        ? formatDateTime(booking.showTime!)
        : 'Time TBA';

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusMd,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surfaceSoft, AppColors.surface],
          ),
          borderRadius: AppRadius.borderRadiusMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      booking.movieTitle ?? 'Unknown Movie',
                      style: AppTextStyles.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  BookingStatusBadge(status: booking.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(showTimeStr, style: AppTextStyles.body)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  const Text('Seats:', style: AppTextStyles.bodySmall),
                  for (final seat in booking.seats)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        seat.seatLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Code: ${booking.bookingCode}',
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    formatVnd(booking.totalAmount),
                    style: AppTextStyles.title.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge({required this.status, super.key});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, variant) = switch (status) {
      BookingStatus.pending => ('Pending', StatusBadgeVariant.warning),
      BookingStatus.confirmed => ('Confirmed', StatusBadgeVariant.success),
      BookingStatus.cancelled => ('Cancelled', StatusBadgeVariant.error),
      BookingStatus.expired => ('Expired', StatusBadgeVariant.neutral),
    };

    return StatusBadge(label: label, variant: variant);
  }
}
