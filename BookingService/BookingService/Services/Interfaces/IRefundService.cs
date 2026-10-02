using BookingService.DTOs.Responses;
using BookingService.Helpers;

namespace BookingService.Services.Interfaces
{
    // Hoàn tiền (FR-PAY-06, luồng 8.2). PayOS không có API hoàn tiền: hệ thống ghi nhận yêu cầu,
    // Staff chuyển khoản trả khách rồi xác nhận kèm mã giao dịch.
    public interface IRefundService
    {
        // Payment đã thanh toán -> yêu cầu hoàn 100%. Gọi lại nhiều lần trả về yêu cầu đã có
        Task<RefundResponse> RequestRefundAsync(long paymentId, string reason);

        // Booking bị huỷ: payment của booking đã thanh toán thì tạo yêu cầu hoàn, không có thì trả null
        Task<RefundResponse?> RequestRefundForBookingAsync(long bookingId, string reason);

        Task<RefundResponse> CompleteRefundAsync(
            long refundId,
            string transactionRef,
            string? note,
            long processedBy);

        Task<PagedResult<RefundResponse>> GetRefundsAsync(string? status, int page, int size);

        Task<RefundResponse> GetRefundByIdAsync(long id);

        Task<RefundResponse> GetRefundByPaymentIdAsync(long paymentId);
    }
}
