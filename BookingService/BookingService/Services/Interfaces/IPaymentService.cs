using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Helpers;

namespace BookingService.Services.Interfaces
{
    public interface IPaymentService
    {
        Task<PagedResult<PaymentResponse>> GetAllPaymentsAsync(
            int page,
            int size,
            string sortBy,
            string sortDir);

        Task<PagedResult<PaymentResponse>> GetPaymentsByUserAsync(
            long userId,
            int page,
            int size,
            string sortBy,
            string sortDir);

        Task<PagedResult<PaymentResponse>> GetPaymentsByBookingAsync(
            long bookingId,
            int page,
            int size,
            string sortBy,
            string sortDir);

        Task<PaymentResponse> GetPaymentByIdAsync(long id);

        Task<PaymentResponse> CreatePaymentAsync(PaymentRequest request);

        Task<PaymentResponse> ProcessPaymentAsync(long id);

        Task<PaymentResponse> RefundPaymentAsync(
            long id,
            string fallbackRecipientEmail);

        Task<PayOsCheckoutResponse> CreatePayOsPaymentAsync(
            PayOsCreateRequest request);

        Task<PaymentResponse> VerifyPayOsPaymentAsync(
            long orderCode);
    }
}
