using System.Text.Json;
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

        Task<PaymentResponse> GetPaymentByOrderCodeAsync(long orderCode);

        Task<PaymentResponse> CreatePaymentAsync(PaymentRequest request);

        Task<PaymentResponse> ProcessPaymentAsync(
            long id,
            string? recipientEmail);

        Task<RefundResponse> RefundPaymentAsync(
            long id,
            string? reason);

        Task<PayOsCheckoutResponse> CreatePayOsPaymentAsync(
            PayOsCreateRequest request);

        // PayOS báo đã thanh toán -> payment SUCCESS và booking được xác nhận tự động
        Task<PaymentResponse> VerifyPayOsPaymentAsync(
            long orderCode,
            string? recipientEmail);

        // PayOS gọi về khi khách thanh toán xong (FR-PAY-07): kiểm tra chữ ký rồi mới cập nhật payment
        Task<PayOsWebhookResult> HandlePayOsWebhookAsync(JsonElement body);

        // Booking hết hạn / bị huỷ khi chưa thanh toán: payment còn PENDING -> FAILED
        Task FailUnpaidPaymentsOfBookingAsync(long bookingId, string reason, bool cancelPayOsLink);
    }
}
