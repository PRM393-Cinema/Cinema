using BookingService.Models;

namespace BookingService.Messaging
{
    // Dựng dữ liệu event từ entity: đủ thông tin để Notification gửi email mà không phải gọi ngược lại service
    public static class EventFactory
    {
        public static BookingEventData Booking(
            Booking booking,
            IEnumerable<BookingSeat> seats,
            string? previousStatus = null,
            string? reason = null,
            string? cancelledBy = null,
            string? recipientEmail = null)
        {
            return new BookingEventData
            {
                BookingId = booking.Id,
                BookingCode = booking.BookingCode,
                UserId = booking.UserId,
                CustomerEmail = booking.CustomerEmail,
                RecipientEmail = recipientEmail,
                ShowtimeId = booking.ShowtimeId,
                MovieTitle = booking.MovieTitle,
                ShowTime = booking.ShowTime,
                Seats = seats.Select(seat => seat.SeatLabel).ToList(),
                TotalAmount = booking.TotalAmount,
                Status = booking.Status,
                PreviousStatus = previousStatus,
                PaymentId = booking.PaymentId,
                ExpiresAt = booking.ExpiresAt,
                Reason = reason,
                CancelledBy = cancelledBy
            };
        }

        public static PaymentEventData Payment(
            Payment payment,
            Booking? booking,
            Refund? refund = null,
            string? reason = null)
        {
            return new PaymentEventData
            {
                PaymentId = payment.Id,
                PaymentCode = payment.PaymentCode,
                BookingId = payment.BookingId,
                BookingCode = booking?.BookingCode,
                UserId = payment.UserId,
                CustomerEmail = booking?.CustomerEmail,
                MovieTitle = booking?.MovieTitle,
                ShowTime = booking?.ShowTime,
                Amount = payment.Amount,
                Method = payment.Method,
                Status = payment.Status,
                RefundId = refund?.Id,
                RefundCode = refund?.RefundCode,
                RefundAmount = refund?.Amount,
                RefundTransactionRef = refund?.TransactionRef,
                Reason = reason ?? refund?.Reason
            };
        }
    }
}
