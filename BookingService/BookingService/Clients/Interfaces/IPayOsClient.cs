using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;

namespace BookingService.Clients.Interfaces
{
    public interface IPayOsClient
    {
        Task<PayOsPaymentLink> CreatePaymentLinkAsync(
            long orderCode,
            decimal amount,
            string description,
            string returnUrl,
            string cancelUrl,
            DateTime? expiresAt = null,
            CancellationToken cancellationToken = default);

        Task<PayOsPaymentStatus> GetPaymentStatusAsync(
            long orderCode,
            CancellationToken cancellationToken = default);
    }

    public sealed class PayOsPaymentLink
    {
        public long OrderCode { get; init; }

        public string? CheckoutUrl { get; init; }

        public string? PaymentLinkId { get; init; }
    }

    public sealed class PayOsPaymentStatus
    {
        public long OrderCode { get; init; }

        public string Status { get; init; } = string.Empty;

        public string? PaymentLinkId { get; init; }

        public string? CheckoutUrl { get; init; }
    }
}