import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/cinema_account_widgets.dart';

class ShiftCharts extends StatelessWidget {
  const ShiftCharts({
    required this.sold,
    required this.held,
    required this.checkedIn,
    required this.withBookings,
    required this.showtimes,
    super.key,
  });

  final int sold;
  final int held;
  final int checkedIn;
  final int withBookings;
  final int showtimes;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final booked = withBookings.clamp(0, showtimes);
    final ratio = showtimes == 0 ? 0.0 : booked / showtimes;
    final bars = [
      ('Sold', sold, colors.primary),
      ('Held', held, colors.warning),
      ('Checked in', checkedIn, colors.success),
    ];
    final maximum = math.max(1, math.max(sold, math.max(held, checkedIn)));
    final panels = <Widget>[
      CinemaPanel(
        key: const Key('ticketChartPanel'),
        surfaceOpacity: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tickets & attendance', style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text(
              'Today’s shows · checked-in tickets are included in sold.',
              style: AppTextStyles.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 104 + 28 * MediaQuery.textScalerOf(context).scale(1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (label, value, color) in bars)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$value', style: AppTextStyles.title),
                              const SizedBox(height: 8),
                              Tooltip(
                                message: '$label: $value tickets',
                                child: Semantics(
                                  label: '$label: $value tickets',
                                  child: ExcludeSemantics(
                                    child: FractionallySizedBox(
                                      widthFactor: 0.55,
                                      child: Container(
                                        key: ValueKey('chartBar-$label'),
                                        height: 88 * value / maximum,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(5),
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(
              key: const Key('ticketChartBaseline'),
              height: 1,
              color: colors.border,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, _, _) in bars)
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  ),
              ],
            ),
            if (sold + held + checkedIn == 0) ...[
              const SizedBox(height: 8),
              Text(
                'No ticket activity yet today.',
                style: AppTextStyles.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
      CinemaPanel(
        key: const Key('coverageChartPanel'),
        surfaceOpacity: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Showtime coverage', style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text(
              'Today · at least one sold or held seat.',
              style: AppTextStyles.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  label: '$booked of $showtimes showtimes have bookings',
                  child: ExcludeSemantics(
                    child: SizedBox(
                      width: 116,
                      height: 116,
                      child: CustomPaint(
                        painter: _CoveragePainter(
                          ratio,
                          colors.primary,
                          colors.border,
                        ),
                        child: Center(
                          child: Text(
                            showtimes == 0 ? '—' : '${(ratio * 100).round()}%',
                            style: AppTextStyles.heading2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Legend(
                      label: 'With bookings',
                      value: booked,
                      color: colors.primary,
                    ),
                    const SizedBox(height: 12),
                    _Legend(
                      label: 'Without bookings',
                      value: showtimes - booked,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$showtimes scheduled showtimes',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 736) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [panels[0], const SizedBox(height: 16), panels[1]],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: panels[0]),
              const SizedBox(width: 16),
              Expanded(child: panels[1]),
            ],
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      Text('$label  $value', style: AppTextStyles.bodySmall),
    ],
  );
}

class _CoveragePainter extends CustomPainter {
  const _CoveragePainter(this.ratio, this.foreground, this.track);
  final double ratio;
  final Color foreground;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(7);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2,
      false,
      paint..color = track,
    );
    if (ratio > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * ratio,
        false,
        paint..color = foreground,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoveragePainter oldDelegate) =>
      ratio != oldDelegate.ratio ||
      foreground != oldDelegate.foreground ||
      track != oldDelegate.track;
}
