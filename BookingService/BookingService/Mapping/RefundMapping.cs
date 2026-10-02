using BookingService.DTOs.Responses;
using BookingService.Models;

namespace BookingService.Mapping
{
    public static class RefundMapping
    {
        public static RefundResponse ToResponse(this Refund refund, Payment? payment = null)
        {
            return new RefundResponse
            {
                Id = refund.Id,
                RefundCode = refund.RefundCode,
                PaymentId = refund.PaymentId,
                BookingId = refund.BookingId,
                UserId = refund.UserId,
                Amount = refund.Amount,
                Reason = refund.Reason,
                Status = refund.Status,
                TransactionRef = refund.TransactionRef,
                Note = refund.Note,
                ProcessedBy = refund.ProcessedBy,
                CreatedAt = refund.CreatedAt,
                ProcessedAt = refund.ProcessedAt,
                PayerAccountNumber = payment?.PayerAccountNumber,
                PayerAccountName = payment?.PayerAccountName,
                PayerBankName = payment?.PayerBankName
            };
        }
    }
}
