import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'json_readers.dart';

// Membership tiers by the money spent on tickets: Member earns 5% back in
// points, VIP (from 2,000,000 ₫) 7%, VVIP (from 5,000,000 ₫) 10%.
enum MemberTier {
  member('MEMBER', 'Member', AppColors.textSecondary),
  vip('VIP', 'VIP', AppColors.warning),
  vvip('VVIP', 'VVIP', AppColors.accent);

  const MemberTier(this.code, this.label, this.color);

  final String code;
  final String label;
  final Color color;

  static MemberTier parse(String? code) => values.firstWhere(
    (tier) => tier.code == code?.toUpperCase(),
    orElse: () => member,
  );
}

// 1 point pays 1,000 ₫; points pay at most half of a booking.
const pointValue = 1000.0;

int maxRedeemablePoints(double orderAmount) =>
    orderAmount <= 0 ? 0 : (orderAmount * 0.5 / pointValue).floor();

// A member's points and tier.
class LoyaltyCard {
  const LoyaltyCard({
    required this.userId,
    required this.points,
    required this.tier,
    this.lifetimeSpend = 0,
    this.earnRatePercent = 5,
    this.nextTier,
    this.nextTierSpend,
    this.history = const [],
  });

  factory LoyaltyCard.fromJson(Map<String, Object?> json) => LoyaltyCard(
    userId: readInt(json['userId']),
    points: readOptionalInt(json['points']) ?? 0,
    tier: MemberTier.parse(readOptionalString(json['tier'])),
    lifetimeSpend: readDouble(json['lifetimeSpend']),
    earnRatePercent: readDouble(json['earnRatePercent']),
    nextTier: json['nextTier'] == null
        ? null
        : MemberTier.parse(readOptionalString(json['nextTier'])),
    nextTierSpend: json['nextTierSpend'] == null
        ? null
        : readDouble(json['nextTierSpend']),
    history: readMapList(json['transactions'])
        .map(LoyaltyLine.fromJson)
        .toList(),
  );

  final int userId;
  final int points;
  final MemberTier tier;

  // Tickets paid for, minus refunds; it sets the tier.
  final double lifetimeSpend;
  final double earnRatePercent;
  final MemberTier? nextTier;
  final double? nextTierSpend;

  // Newest first.
  final List<LoyaltyLine> history;

  double get pointsValue => points * pointValue;

  // How far the member is to the next tier (0 to 1); null at the top tier.
  double? get progress => nextTierSpend == null || nextTierSpend! <= 0
      ? null
      : (lifetimeSpend / nextTierSpend!).clamp(0, 1).toDouble();

  // The points this member can use on an order of [orderAmount].
  int usableOn(double orderAmount) {
    final max = maxRedeemablePoints(orderAmount);
    return points < max ? points : max;
  }
}

// One change of a member's points.
class LoyaltyLine {
  const LoyaltyLine({
    required this.id,
    required this.type,
    required this.points,
    required this.createdAt,
    this.bookingId,
    this.note,
  });

  factory LoyaltyLine.fromJson(Map<String, Object?> json) => LoyaltyLine(
    id: readInt(json['id']),
    type: readString(json['type']).toUpperCase(),
    points: readOptionalInt(json['points']) ?? 0,
    bookingId: readOptionalInt(json['bookingId']),
    note: readOptionalString(json['note']),
    createdAt: readRequiredDateTime(json['createdAt']),
  );

  final int id;

  // EARN, REDEEM, RETURN, REVERSE or ADJUST.
  final String type;

  // Positive: added; negative: taken away.
  final int points;
  final int? bookingId;

  // The ticket code, or the admin's reason.
  final String? note;
  final DateTime createdAt;

  String get label => switch (type) {
    'EARN' => 'Earned from a ticket',
    'REDEEM' => 'Used on a ticket',
    'RETURN' => 'Returned (ticket not paid)',
    'REVERSE' => 'Taken back (ticket cancelled)',
    'ADJUST' => 'Changed by the cinema',
    _ => type,
  };

  String get pointsText => points > 0 ? '+$points' : '$points';
}

// A customer account found by phone number at the counter.
class MemberLookup {
  const MemberLookup({
    required this.userId,
    required this.email,
    this.fullName,
    this.phone,
  });

  factory MemberLookup.fromJson(Map<String, Object?> json) => MemberLookup(
    userId: readInt(json['userId']),
    email: readString(json['email']),
    fullName: readOptionalString(json['fullName']),
    phone: readOptionalString(json['phone']),
  );

  final int userId;
  final String email;
  final String? fullName;
  final String? phone;

  String get displayName =>
      fullName == null || fullName!.trim().isEmpty ? email : fullName!;
}
