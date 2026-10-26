import '../../data/models/payment.dart';

// PayOS sends the browser back to the return/cancel URL with
// ?code=..&id=..&cancel=..&status=..&orderCode=.. appended.
class PayOsReturn {
  const PayOsReturn({required this.orderCode, required this.cancelled});

  final int orderCode;
  final bool cancelled;

  static PayOsReturn? fromUri(Uri uri) {
    final orderCode = int.tryParse(uri.queryParameters['orderCode'] ?? '');
    if (orderCode == null) {
      return null;
    }

    return PayOsReturn(
      orderCode: orderCode,
      cancelled:
          uri.queryParameters['cancel'] == 'true' ||
          uri.queryParameters['status'] == 'CANCELLED',
    );
  }
}

class PaymentResultArgs {
  const PaymentResultArgs({required this.bookingId, this.payment});

  // The booking, or the PayOS order code when PayOS sent the browser back:
  // the result page then finds the booking from the verified payment.
  final int bookingId;

  // Result of a verify call made before opening the screen. When null the
  // screen verifies the payment itself.
  final PaymentInfo? payment;
}
