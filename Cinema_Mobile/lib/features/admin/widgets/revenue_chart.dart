import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cinema_account_widgets.dart';

class RevenueChart extends StatefulWidget {
  const RevenueChart({required this.days, super.key});
  final List<(DateTime, double)> days;

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final colors = AppPalette.of(context);
    if (days.isEmpty) return const SizedBox.shrink();
    final selected = (_selected ?? days.length - 1).clamp(0, days.length - 1);
    final maximum = math.max(1.0, days.map((day) => day.$2).reduce(math.max));
    final axisFormat = NumberFormat.compactCurrency(
      symbol: '₫',
      decimalDigits: 1,
    );
    final dateFormat = DateFormat('dd/MM');
    return CinemaPanel(
      key: const Key('monthlyRevenueChart'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Daily revenue', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'VND · ${dateFormat.format(days.first.$1)} – ${dateFormat.format(days.last.$1)} · received payments, including pending refunds.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Day details',
              isDense: true,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                key: const Key('revenueDaySelector'),
                value: selected,
                isDense: true,
                isExpanded: true,
                items: [
                  for (var i = 0; i < days.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${dateFormat.format(days[i].$1)} · ${formatVnd(days[i].$2)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (day) {
                  if (day != null) setState(() => _selected = day);
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 64,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final value in [maximum, maximum / 2, 0.0])
                        Text(
                          axisFormat.format(value),
                          style: AppTextStyles.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => MouseRegion(
                      onHover: (event) {
                        final index = days.length == 1
                            ? 0
                            : ((event.localPosition.dx - 4) /
                                      math.max(1, constraints.maxWidth - 8) *
                                      (days.length - 1))
                                  .round()
                                  .clamp(0, days.length - 1);
                        if (index != selected) {
                          setState(() => _selected = index);
                        }
                      },
                      child: Semantics(
                        label:
                            'Daily revenue ${dateFormat.format(days[selected].$1)}: ${formatVnd(days[selected].$2)}',
                        child: CustomPaint(
                          key: const Key('revenueLinePlot'),
                          painter: RevenueLinePainter(
                            values: [for (final day in days) day.$2],
                            selected: selected,
                            maximum: maximum,
                            color: colors.primary,
                            gridColor: colors.border,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(days.first.$1),
                  style: AppTextStyles.caption,
                ),
                if (days.length > 2 && days.length.isOdd)
                  Text(
                    dateFormat.format(days[days.length ~/ 2].$1),
                    style: AppTextStyles.caption,
                  ),
                if (days.length > 1)
                  Text(
                    dateFormat.format(days.last.$1),
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
          if (days.every((day) => day.$2 == 0)) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'No revenue recorded this month.',
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class RevenueLinePainter extends CustomPainter {
  const RevenueLinePainter({
    required this.values,
    required this.selected,
    required this.maximum,
    required this.color,
    required this.gridColor,
  });
  final List<double> values;
  final int selected;
  final double maximum;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final y in [4.0, size.height / 2, size.height - 4]) {
      canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), grid);
    }
    if (values.isEmpty) return;
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          values.length == 1
              ? size.width / 2
              : 4 + (size.width - 8) * i / (values.length - 1),
          size.height - 4 - (size.height - 8) * values[i] / maximum,
        ),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(
        points[i],
        i == selected ? 4 : 2.5,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RevenueLinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.selected != selected ||
      oldDelegate.maximum != maximum ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}
