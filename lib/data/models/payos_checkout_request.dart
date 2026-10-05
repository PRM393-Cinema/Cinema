class PayOsCheckoutRequest {
  const PayOsCheckoutRequest({
    required this.bookingId,
    required this.amount,
    required this.returnUrl,
    required this.cancelUrl,
  });

  final int bookingId;

  // Must equal the booking total; the backend rejects any other amount.
  final double amount;
  final String returnUrl;
  final String cancelUrl;

  Map<String, Object?> toJson() {
    return {
      'bookingId': bookingId,
      'amount': amount,
      'returnUrl': returnUrl,
      'cancelUrl': cancelUrl,
    };
  }
}
