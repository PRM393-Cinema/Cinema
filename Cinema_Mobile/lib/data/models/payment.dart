import 'json_readers.dart';

enum PaymentStatus {
  pending,
  success,
  failed,
  refundPending,
  refunded,
  unknown;

  static PaymentStatus parse(String value) {
    return switch (value.toUpperCase()) {
      'PENDING' => PaymentStatus.pending,
      'SUCCESS' => PaymentStatus.success,
      'FAILED' => PaymentStatus.failed,
      'REFUND_PENDING' => PaymentStatus.refundPending,
      'REFUNDED' => PaymentStatus.refunded,
      _ => PaymentStatus.unknown,
    };
  }
}

// Ticket sales over a period (admin dashboard).
class PaymentSummary {
  const PaymentSummary({
    required this.paidCount,
    required this.revenue,
    required this.refundedAmount,
  });

  factory PaymentSummary.fromJson(Map<String, Object?> json) => PaymentSummary(
    paidCount: readOptionalInt(json['paidCount']) ?? 0,
    revenue: readDouble(json['revenue']),
    refundedAmount: readDouble(json['refundedAmount']),
  );

  // Payments received (refunds not yet completed included).
  final int paidCount;
  final double revenue;
  final double refundedAmount;
}

class PaymentInfo {
  const PaymentInfo({
    required this.id,
    required this.paymentCode,
    required this.bookingId,
    required this.amount,
    required this.status,
    this.method,
    this.transactionRef,
    required this.createdAt,
  });

  factory PaymentInfo.fromJson(Map<String, Object?> json) {
    return PaymentInfo(
      id: readInt(json['id']),
      paymentCode: readString(json['paymentCode']),
      bookingId: readInt(json['bookingId']),
      amount: readDouble(json['amount']),
      status: PaymentStatus.parse(readString(json['status'])),
      method: readOptionalString(json['method']),
      transactionRef: readOptionalString(json['transactionRef']),
      createdAt: readRequiredDateTime(json['createdAt']),
    );
  }

  final int id;
  final String paymentCode;
  final int bookingId;
  final double amount;
  final PaymentStatus status;
  final String? method;
  final String? transactionRef;
  final DateTime createdAt;
}

class PayOsCheckout {
  const PayOsCheckout({
    required this.paymentId,
    required this.orderCode,
    this.checkoutUrl,
    this.qrCode,
  });

  factory PayOsCheckout.fromJson(Map<String, Object?> json) {
    return PayOsCheckout(
      paymentId: readInt(json['paymentId']),
      orderCode: readInt(json['orderCode']),
      checkoutUrl: readOptionalString(json['checkoutUrl']),
      qrCode: readOptionalString(json['qrCode']),
    );
  }

  final int paymentId;

  // The PayOS order code is the booking id.
  final int orderCode;
  final String? checkoutUrl;

  // The VietQR a banking app pays. PayOS only returns it when the link is
  // created, so a link made earlier has just its checkout page.
  final String? qrCode;
}

class Refund {
  const Refund({
    required this.id,
    required this.refundCode,
    required this.paymentId,
    required this.amount,
    required this.status,
    this.transactionRef,
    required this.createdAt,
    this.processedAt,
    this.bookingId,
    this.reason,
    this.payerAccountNumber,
    this.payerAccountName,
    this.payerBankName,
    this.note,
  });

  factory Refund.fromJson(Map<String, Object?> json) {
    return Refund(
      id: readInt(json['id']),
      refundCode: readString(json['refundCode']),
      paymentId: readInt(json['paymentId']),
      amount: readDouble(json['amount']),
      status: readString(json['status'], fallback: 'PENDING'),
      transactionRef: readOptionalString(json['transactionRef']),
      createdAt: readRequiredDateTime(json['createdAt']),
      processedAt: readDateTime(json['processedAt']),
      bookingId: readOptionalInt(json['bookingId']),
      reason: readOptionalString(json['reason']),
      payerAccountNumber: readOptionalString(json['payerAccountNumber']),
      payerAccountName: readOptionalString(json['payerAccountName']),
      payerBankName: readOptionalString(json['payerBankName']),
      note: readOptionalString(json['note']),
    );
  }

  final int id;
  final String refundCode;
  final int paymentId;
  final double amount;
  final String status; // 'PENDING', 'COMPLETED', 'REJECTED'
  final String? transactionRef;
  final DateTime createdAt;
  final DateTime? processedAt;
  final int? bookingId;
  final String? reason;
  final String? payerAccountNumber;
  final String? payerAccountName;
  final String? payerBankName;
  final String? note;

  bool get isCompleted => status == 'COMPLETED';
  bool get isPending => status == 'PENDING';
  bool get isRejected => status == 'REJECTED';
}
