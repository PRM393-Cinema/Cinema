import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/responsive_columns.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/payment.dart';

// Scoped to booking details; the rest of the app keeps its current theme.
ThemeData bookingDetailTheme(ThemeData base) {
  final dark = base.brightness == Brightness.dark;
  final palette = AppPalette(isLight: !dark);
  final foreground = dark ? const Color(0xFFF1F5F9) : palette.textPrimary;
  final muted = dark ? const Color(0xFF94A3B8) : palette.textSecondary;
  final border = dark ? const Color(0xFF28303D) : palette.border;
  final accent = dark ? const Color(0xFF22C7D8) : palette.primary;
  return base.copyWith(
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0B0F14)
        : palette.background,
    dividerColor: border,
    colorScheme: base.colorScheme.copyWith(
      surface: dark ? const Color(0xFF141922) : palette.surface,
      onSurface: foreground,
      onSurfaceVariant: muted,
      outline: border,
      outlineVariant: border,
      primary: accent,
      onPrimary: dark ? const Color(0xFF0B0F14) : Colors.white,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'BookingInter',
      bodyColor: foreground,
      displayColor: foreground,
    ),
    iconTheme: IconThemeData(color: muted, size: 16),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: muted,
        focusColor: accent.withValues(alpha: 0.18),
        hoverColor: foreground.withValues(alpha: 0.06),
        minimumSize: const Size(44, 44),
        iconSize: 16,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(color: border),
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(fontFamily: 'BookingInter', fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}

abstract final class BookingDetailIcons {
  static const copy = IconData(0xe0a2, fontFamily: 'BookingLucide');
  static const calendar = IconData(0xe067, fontFamily: 'BookingLucide');
  static const clock = IconData(0xe08b, fontFamily: 'BookingLucide');
  static const ticket = IconData(0xe20e, fontFamily: 'BookingLucide');
  static const receipt = IconData(0xe3d6, fontFamily: 'BookingLucide');
  static const history = IconData(0xe1f4, fontFamily: 'BookingLucide');
  static const check = IconData(0xe225, fontFamily: 'BookingLucide');
  static const cancel = IconData(0xe088, fontFamily: 'BookingLucide');
  static const refund = IconData(0xe14b, fontFamily: 'BookingLucide');
  static const qr = IconData(0xe1de, fontFamily: 'BookingLucide');
  static const back = IconData(0xe04c, fontFamily: 'BookingLucide');
}

class BookingDetailContent extends StatelessWidget {
  const BookingDetailContent({
    required this.booking,
    this.refund,
    this.actions,
    this.shareActions,
    this.lateNote,
    super.key,
  });

  final Booking booking;
  final Refund? refund;
  final Widget? actions;
  final Widget? shareActions;
  final Widget? lateNote;

  Future<void> _copyCode(BuildContext context) async {
    String message;
    try {
      await Clipboard.setData(ClipboardData(text: booking.bookingCode));
      message = 'Booking code copied';
    } on Object {
      message = 'Could not copy booking code. Please select and copy it.';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = booking.showTime;
    final hasTicket = booking.status == BookingStatus.confirmed;
    final header = _Section(
      key: const Key('bookingInformation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Your booking', style: _muted(context)),
              _BookingBadge(booking: booking),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text(
              booking.movieTitle ?? 'Unknown Movie',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Booking code', style: _muted(context)),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  booking.bookingCode,
                  style: _body(context).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                key: const Key('copyBookingCode'),
                tooltip: 'Copy booking code',
                onPressed: () => _copyCode(context),
                icon: const Icon(BookingDetailIcons.copy),
              ),
            ],
          ),
          const _SectionDivider(),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 440
                  ? 3
                  : constraints.maxWidth >= 280
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * AppSpacing.lg) /
                  columns;
              return Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: [
                  SizedBox(
                    width: width,
                    child: _Metadata(
                      icon: BookingDetailIcons.calendar,
                      label: 'Show date',
                      value: date == null ? 'TBA' : formatDate(date),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _Metadata(
                      icon: BookingDetailIcons.clock,
                      label: 'Show time',
                      value: date == null ? 'TBA' : formatTime(date),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _Metadata(
                      icon: BookingDetailIcons.ticket,
                      label: 'Tickets',
                      value: '${booking.seats.length}',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
    final seats = _Section(
      key: const Key('bookingSeatsSection'),
      title: 'Seats & Tickets',
      icon: BookingDetailIcons.ticket,
      trailing: Text(
        formatCount(booking.seats.length, 'ticket'),
        style: _muted(context),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final seat in booking.seats)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: colors.outline),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                seat.seatLabel,
                style: _body(context).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final split =
            constraints.maxWidth >= 960 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.6;
        return ResponsiveColumns(
          sideBySideFrom: split ? 960 : double.infinity,
          sideWidth: (constraints.maxWidth - AppSpacing.xl) / 3,
          main: [
            header,
            const SizedBox(height: AppSpacing.xl),
            seats,
            const SizedBox(height: AppSpacing.xl),
            _Timeline(booking: booking, refund: refund),
            if (hasTicket) ...[
              const SizedBox(height: AppSpacing.xl),
              _Section(
                key: const Key('ticketQr'),
                title: 'Your ticket',
                icon: BookingDetailIcons.qr,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Opacity(
                        opacity: booking.isCheckedIn ? 0.35 : 1,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: QrImageView(
                            data: booking.bookingCode,
                            size: 180,
                            backgroundColor: Colors.white,
                            semanticsLabel:
                                'Ticket QR code ${booking.bookingCode}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      booking.checkedInAt == null
                          ? 'Show this QR code at the cinema to check in.'
                          : 'Checked in ${formatDateTime(booking.checkedInAt!)}',
                      textAlign: TextAlign.center,
                      style: _muted(context),
                    ),
                    if (shareActions != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Center(child: shareActions!),
                    ],
                  ],
                ),
              ),
            ],
          ],
          side: [
            if (!split) const SizedBox(height: AppSpacing.xl),
            _PaymentSummary(booking: booking, refund: refund),
            if (refund != null ||
                booking.status == BookingStatus.refundPending) ...[
              const SizedBox(height: AppSpacing.xl),
              _RefundStatus(refund: refund),
            ],
            if (lateNote != null) ...[
              const SizedBox(height: AppSpacing.lg),
              lateNote!,
            ],
            if (actions != null) ...[
              const SizedBox(height: AppSpacing.xl),
              actions!,
            ],
          ],
        );
      },
    );
  }
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.booking, this.refund});
  final Booking booking;
  final Refund? refund;

  @override
  Widget build(BuildContext context) {
    final ticketAmount = booking.seats.fold<double>(
      0,
      (sum, seat) => sum + seat.price,
    );
    final subtotal = ticketAmount + booking.concessionsAmount;
    final paid =
        booking.status == BookingStatus.confirmed ||
        booking.status == BookingStatus.refundPending ||
        refund != null;
    return _Section(
      key: const Key('bookingPaymentSummary'),
      title: 'Payment Summary',
      icon: BookingDetailIcons.receipt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryRow(
            label: 'Tickets (${booking.seats.length})',
            value: formatVnd(ticketAmount),
          ),
          for (final snack in booking.concessions)
            _SummaryRow(
              label: '${snack.name} (${snack.quantity})',
              value: formatVnd(snack.amount),
            ),
          if (booking.concessions.isEmpty && booking.concessionsAmount > 0)
            _SummaryRow(
              label: 'Concessions',
              value: formatVnd(booking.concessionsAmount),
            ),
          const _SectionDivider(),
          _SummaryRow(label: 'Subtotal', value: formatVnd(subtotal)),
          _SummaryRow(
            key: const Key('bookingDiscount'),
            label: 'Discount',
            value: booking.hasDiscount
                ? '-${formatVnd(booking.discountAmount)}'
                : formatVnd(0),
          ),
          if (booking.promotionName != null || booking.promotionCode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                booking.promotionName ?? booking.promotionCode!,
                style: _muted(context),
              ),
            ),
          if (booking.pointsUsed > 0)
            _SummaryRow(
              key: const Key('bookingPointsUsed'),
              label: '${booking.pointsUsed} points redeemed',
              value: '-${formatVnd(booking.pointsDiscount)}',
            ),
          const _SectionDivider(),
          Text(paid ? 'Total Paid' : 'Total Amount', style: _muted(context)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatVnd(booking.totalAmount),
            key: const Key('bookingTotal'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              height: 1.2,
              letterSpacing: 0,
            ),
          ),
          if (booking.pointsEarned > 0 || booking.paymentId != null) ...[
            const _SectionDivider(),
            if (booking.pointsEarned > 0)
              _SummaryRow(
                key: const Key('bookingPointsEarned'),
                label: 'Reward points',
                value: '${booking.pointsEarned} points',
              ),
            if (booking.paymentId != null)
              _SummaryRow(label: 'Payment ID', value: '${booking.paymentId}'),
          ],
        ],
      ),
    );
  }
}

class _RefundStatus extends StatelessWidget {
  const _RefundStatus({this.refund});
  final Refund? refund;

  @override
  Widget build(BuildContext context) {
    final item = refund;
    final label = item == null || item.isPending
        ? 'Refund Pending'
        : item.isCompleted
        ? 'Refund completed'
        : item.isRejected
        ? 'Refund request rejected'
        : item.status;
    final color = item?.isCompleted == true
        ? AppPalette.of(context).success
        : item?.isRejected == true
        ? AppPalette.of(context).error
        : AppPalette.of(context).warning;
    return _Section(
      key: const Key('bookingRefundStatus'),
      title: 'Refund Status',
      icon: BookingDetailIcons.refund,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Badge(label: label, color: color),
          if (item != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Refund Amount', style: _muted(context)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              formatVnd(item.amount),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                height: 1.2,
                letterSpacing: 0,
              ),
            ),
            const _SectionDivider(),
            Text('Refund ID', style: _muted(context)),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(item.refundCode, style: _body(context)),
            if (item.reason?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Reason', style: _muted(context)),
              const SizedBox(height: AppSpacing.xs),
              Text(item.reason!, style: _body(context)),
            ],
            if (item.note?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                item.isRejected ? 'Rejection reason' : 'Staff note',
                style: _muted(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              SelectableText(
                item.note!,
                style: _body(context).copyWith(fontSize: 16, height: 1.5),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.booking, this.refund});
  final Booking booking;
  final Refund? refund;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // Booking has no paidAt or cancelledAt. Only render recorded timestamps.
    final events = <({String label, DateTime at, IconData icon, Color color})>[
      (
        label: 'Created',
        at: booking.createdAt,
        icon: BookingDetailIcons.ticket,
        color: muted,
      ),
      if (booking.checkedInAt case final at?)
        (
          label: 'Checked in',
          at: at,
          icon: BookingDetailIcons.check,
          color: palette.success,
        ),
      if (refund case final item?) ...[
        (
          label: 'Refund requested',
          at: item.createdAt,
          icon: BookingDetailIcons.refund,
          color: palette.warning,
        ),
        if (item.processedAt case final at?)
          if (item.isCompleted || item.isRejected)
            (
              label: item.isCompleted ? 'Refund completed' : 'Refund rejected',
              at: at,
              icon: item.isCompleted
                  ? BookingDetailIcons.check
                  : BookingDetailIcons.cancel,
              color: item.isCompleted ? palette.success : palette.error,
            ),
      ],
      if (booking.status == BookingStatus.pending)
        if (booking.expiresAt case final at?)
          (
            label: 'Expires',
            at: at,
            icon: BookingDetailIcons.clock,
            color: palette.warning,
          ),
    ]..sort((a, b) => a.at.compareTo(b.at));
    return _Section(
      key: const Key('bookingTimeline'),
      title: 'Timeline',
      icon: BookingDetailIcons.history,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, event) in events.indexed)
            Stack(
              children: [
                if (index < events.length - 1)
                  Positioned(
                    left: 11,
                    top: 26,
                    bottom: 0,
                    child: ColoredBox(
                      color: Theme.of(context).dividerColor,
                      child: const SizedBox(width: 1),
                    ),
                  ),
                Positioned(
                  left: 4,
                  top: 2,
                  child: Icon(event.icon, size: 16, color: event.color),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: 36,
                    bottom: index < events.length - 1 ? AppSpacing.xl : 0,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final timestamp = Text(
                        formatDateTime(event.at),
                        style: _muted(context),
                      );
                      final label = Text(event.label, style: _body(context));
                      if (constraints.maxWidth < 420 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            label,
                            const SizedBox(height: AppSpacing.xs),
                            timestamp,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: label),
                          const SizedBox(width: AppSpacing.lg),
                          timestamp,
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    super.key,
  });
  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Flexible(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title!,
                          style: _body(
                            context,
                          ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          child,
        ],
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: _muted(context))),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(value, style: _body(context).copyWith(fontWeight: FontWeight.w500)),
    ],
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 210 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: _muted(context)),
              const SizedBox(height: AppSpacing.xs),
              Text(value, style: _body(context), textAlign: TextAlign.end),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: Text(label, style: _muted(context))),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 6,
              child: Text(
                value,
                style: _body(context),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Divider(height: 1, thickness: 1),
  );
}

class _BookingBadge extends StatelessWidget {
  const _BookingBadge({required this.booking});
  final Booking booking;
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final (label, color) = switch (booking.status) {
      BookingStatus.pending => ('Pending', palette.warning),
      BookingStatus.confirmed => (
        booking.isCheckedIn ? 'Checked in' : 'Confirmed',
        palette.success,
      ),
      BookingStatus.refundPending => ('Refund pending', palette.warning),
      BookingStatus.cancelled => ('Cancelled', palette.error),
      BookingStatus.expired => (
        'Expired',
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };
    return _Badge(label: label, color: color);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    widthFactor: 1,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: _body(context)
            .copyWith(fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

TextStyle _body(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium!
        .copyWith(fontSize: 14, height: 1.5, letterSpacing: 0);
TextStyle _muted(BuildContext context) =>
    _body(context)
        .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
