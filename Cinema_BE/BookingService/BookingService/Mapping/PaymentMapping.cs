using BookingService.DTOs.Responses;
using BookingService.Models;

namespace BookingService.Mapping
{
    public static class PaymentMapping
    {
        public static PaymentResponse ToResponse(this Payment payment)
        {
            return new PaymentResponse
            {
                Id = payment.Id,
                PaymentCode = payment.PaymentCode,
                BookingId = payment.BookingId,
                UserId = payment.UserId,
                RecipientEmail = string.Empty,
                Amount = payment.Amount,
                Method = payment.Method,
                Status = payment.Status,
                TransactionRef = payment.TransactionRef,
                CreatedAt = payment.CreatedAt,
                UpdatedAt = payment.UpdatedAt
            };
        }
    }
}