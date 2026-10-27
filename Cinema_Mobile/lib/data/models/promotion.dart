import '../../core/utils/formatters.dart';
import 'json_readers.dart';

// A discount on the ticket price (never on snacks). Without a code it applies
// by itself when the booking qualifies; with one the customer types the code.
class Promotion {
  const Promotion({
    required this.id,
    required this.name,
    required this.discountType,
    required this.discountValue,
    this.code,
    this.description = '',
    this.maxDiscount,
    this.minTickets = 1,
    this.daysOfWeek = const [],
    this.startsAt,
    this.endsAt,
    this.usageLimit,
    this.usedCount = 0,
    this.active = true,
  });

  factory Promotion.fromJson(Map<String, Object?> json) => Promotion(
    id: readInt(json['id']),
    code: readOptionalString(json['code']),
    name: readString(json['name']),
    description: readString(json['description']),
    discountType: readString(json['discountType']).toUpperCase(),
    discountValue: readDouble(json['discountValue']),
    maxDiscount: json['maxDiscount'] == null
        ? null
        : readDouble(json['maxDiscount']),
    minTickets: readOptionalInt(json['minTickets']) ?? 1,
    daysOfWeek: json['daysOfWeek'] is List
        ? (json['daysOfWeek']! as List).map(readInt).toList()
        : const [],
    startsAt: readDateTime(json['startsAt']),
    endsAt: readDateTime(json['endsAt']),
    usageLimit: readOptionalInt(json['usageLimit']),
    usedCount: readOptionalInt(json['usedCount']) ?? 0,
    active: json['active'] != false,
  );

  static const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final int id;

  // Null: applied automatically.
  final String? code;
  final String name;
  final String description;

  // PERCENT or AMOUNT.
  final String discountType;
  final double discountValue;

  // The cap of a percentage discount.
  final double? maxDiscount;
  final int minTickets;

  // Days of the show, 1 = Monday ... 7 = Sunday; empty: every day.
  final List<int> daysOfWeek;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? usageLimit;

  // Paid bookings that used it.
  final int usedCount;
  final bool active;

  bool get isPercent => discountType == 'PERCENT';

  bool get isAutomatic => code == null;

  String get discountText => isPercent
      ? '${discountValue.round()}% off tickets'
            '${maxDiscount == null ? '' : ', up to ${formatVnd(maxDiscount!)}'}'
      : '${formatVnd(discountValue)} off tickets';

  // Who can use it, e.g. "From 2 tickets · Tue".
  String get conditionsText => [
    if (minTickets > 1) 'From $minTickets tickets',
    if (daysOfWeek.isNotEmpty)
      daysOfWeek.map((day) => dayNames[day - 1]).join(', ')
    else
      'Every day',
    if (startsAt != null) 'from ${formatDate(startsAt!)}',
    if (endsAt != null) 'until ${formatDate(endsAt!)}',
  ].join(' · ');

  bool isEnded(DateTime now) =>
      (endsAt != null && endsAt!.isBefore(now)) ||
      (usageLimit != null && usedCount >= usageLimit!);
}

// The discount a booking would get. [discount] is 0 when nothing applies.
class PromotionQuote {
  const PromotionQuote({
    this.promotionId,
    this.code,
    this.name,
    this.description,
    this.discount = 0,
  });

  factory PromotionQuote.fromJson(Map<String, Object?> json) => PromotionQuote(
    promotionId: readOptionalInt(json['promotionId']),
    code: readOptionalString(json['code']),
    name: readOptionalString(json['name']),
    description: readOptionalString(json['description']),
    discount: readDouble(json['discount']),
  );

  static const none = PromotionQuote();

  final int? promotionId;
  final String? code;
  final String? name;
  final String? description;
  final double discount;
}

// Asks the server what a booking would save; [code] null finds the best
// automatic deal. A wrong or unusable code throws its reason.
typedef PromotionQuoter = Future<PromotionQuote> Function({
  required int showtimeId,
  required double ticketAmount,
  required int tickets,
  String? code,
});
