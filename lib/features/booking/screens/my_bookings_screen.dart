import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/mock/mock_bookings.dart';
import '../../../data/models/booking.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Local frontend filtering for UI review
    final activeBookings = mockBookings.where((b) {
      return b.status == BookingStatus.pending || b.status == BookingStatus.confirmed;
    }).toList();

    final historyBookings = mockBookings.where((b) {
      return b.status == BookingStatus.cancelled || b.status == BookingStatus.expired;
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
        body: TabBarView(
          children: [
            _BookingList(bookings: activeBookings),
            _BookingList(bookings: historyBookings),
          ],
        ),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const Center(
        child: Text(
          'No bookings found.',
          style: AppTextStyles.bodySmall,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _BookingCard(booking: booking);
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final String showTimeStr = booking.showTime != null
        ? dateFormat.format(booking.showTime!)
        : 'Time TBA';
    
    final seatLabels = booking.seats.map((s) => s.seatLabel).join(', ');

    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.bookingDetail,
          arguments: booking,
        );
      },
      borderRadius: AppRadius.borderRadiusMd,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
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
                  _BookingStatusBadge(status: booking.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(showTimeStr, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Seats: $seatLabels',
                style: AppTextStyles.bodySmall,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Code: ${booking.bookingCode}',
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    '\$${booking.totalAmount.toStringAsFixed(2)}',
                    style: AppTextStyles.body,
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

class _BookingStatusBadge extends StatelessWidget {
  const _BookingStatusBadge({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final String label;
    final StatusBadgeVariant variant;

    switch (status) {
      case BookingStatus.pending:
        label = 'Pending';
        variant = StatusBadgeVariant.warning;
        break;
      case BookingStatus.confirmed:
        label = 'Confirmed';
        variant = StatusBadgeVariant.success;
        break;
      case BookingStatus.cancelled:
        label = 'Cancelled';
        variant = StatusBadgeVariant.error;
        break;
      case BookingStatus.expired:
        label = 'Expired';
        variant = StatusBadgeVariant.neutral;
        break;
    }

    return StatusBadge(label: label, variant: variant);
  }
}
