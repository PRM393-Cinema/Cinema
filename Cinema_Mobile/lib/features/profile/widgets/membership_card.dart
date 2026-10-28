import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/models/loyalty.dart';

// The member's tier as a small coloured label.
class TierBadge extends StatelessWidget {
  const TierBadge({required this.tier, super.key});

  final MemberTier tier;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.15),
        border: Border.all(color: tier.color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          tier.label,
          style: AppTextStyles.caption.copyWith(
            color: tier.color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// The member card on the profile: points and what they are worth, the tier,
// how far the next tier is, and the latest changes of the points.
class MembershipCard extends StatelessWidget {
  const MembershipCard({
    required this.card,
    this.historySize = 10,
    this.onHistory,
    super.key,
  });

  final LoyaltyCard card;
  final int historySize;
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    final progress = card.progress;
    final next = card.nextTier;
    final history = card.history.take(historySize).toList();
    return CinemaPanel(
      key: const Key('membershipCard'),
      padding: const EdgeInsets.all(AppSpacing.md),
      surfaceOpacity: 0.8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.card_membership_outlined,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text('Membership', style: AppTextStyles.title),
              ),
              TierBadge(tier: card.tier),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${card.points} points',
            key: const Key('memberPoints'),
            style: AppTextStyles.heading2.copyWith(color: AppColors.primary),
          ),
          Text(
            '${formatVnd(card.pointsValue)} · Earn ${card.earnRatePercent.round()}% back',
            style: AppTextStyles.bodySmall,
          ),
          if (progress != null && next != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.surfaceSoft,
                color: next.color,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${formatVnd(card.nextTierSpend! - card.lifetimeSpend)} to ${next.label}',
              style: AppTextStyles.bodySmall,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'You are at the top tier.',
              style: AppTextStyles.bodySmall,
            ),
          ],
          if (onHistory != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton.secondary(
                key: const Key('pointHistory'),
                label: 'Point history',
                leadingIcon: Icons.history_rounded,
                trailingIcon: Icons.chevron_right_rounded,
                onPressed: onHistory,
              ),
            ),
          ] else if (history.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text('Points history', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            for (final line in history) PointsLine(line: line),
          ],
        ],
      ),
    );
  }
}

class PointsLine extends StatelessWidget {
  const PointsLine({required this.line, super.key});

  final LoyaltyLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.label, style: AppTextStyles.body),
                Text(
                  [
                    formatDateTime(line.createdAt),
                    if (line.note != null) line.note!,
                  ].join(' · '),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            line.pointsText,
            style: AppTextStyles.title.copyWith(
              color: line.points >= 0 ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

// "Use N points" on a booking: the most the member can use on [orderAmount].
class UsePointsTile extends StatelessWidget {
  const UsePointsTile({
    required this.card,
    required this.orderAmount,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final LoyaltyCard card;
  final double orderAmount;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final usable = card.usableOn(orderAmount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TierBadge(tier: card.tier),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${card.points} points (${formatVnd(card.pointsValue)})',
                style: AppTextStyles.body,
              ),
            ),
          ],
        ),
        if (usable > 0)
          SwitchListTile(
            key: const Key('usePoints'),
            contentPadding: EdgeInsets.zero,
            title: Text('Use $usable points'),
            subtitle: Text(
              '−${formatVnd(usable * pointValue)} · at most half of the price',
              style: AppTextStyles.bodySmall,
            ),
            value: value,
            onChanged: enabled ? onChanged : null,
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              card.points == 0
                  ? 'Earn ${card.earnRatePercent.round()}% back in points '
                        'once this booking is paid.'
                  : 'Points pay at most half of the price.',
              style: AppTextStyles.bodySmall,
            ),
          ),
      ],
    );
  }
}
