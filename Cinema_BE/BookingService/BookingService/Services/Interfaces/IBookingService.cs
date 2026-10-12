using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Helpers;

namespace BookingService.Services.Interfaces
{
    public interface IBookingService
    {
        Task<PagedResult<BookingResponse>> GetAllBookingsAsync(
            int page,
            int size,
            string sortBy,
            string sortDir);

        Task<PagedResult<BookingResponse>> GetBookingsByUserAsync(
            long userId,
            int page,
            int size,
            string sortBy,
            string sortDir);

        Task<PagedResult<BookingResponse>> GetBookingsByStatusAsync(
            string status,
            int page,
            int size,
            string sortBy,
            string sortDir);

        Task<PagedResult<BookingResponse>> GetBookingsByDateRangeAsync(
            DateTime start,
            DateTime end,
            int page,
            int size,
            string sortBy,
            string sortDir);

        Task<BookingResponse> GetBookingByIdAsync(long id);

        Task<BookingResponse> CreateBookingAsync(
            BookingRequest request);

        Task<BookingResponse> ConfirmBookingAsync(
            long id,
            string paymentMethod,
            string? recipientEmail);

        /// <summary>
        /// Hệ thống tự xác nhận booking sau khi thanh toán online thành công.
        /// Gọi lại nhiều lần vẫn an toàn: booking đã CONFIRMED thì trả về luôn.
        /// Không xác nhận được (ghế đã thuộc booking khác, booking đã huỷ) thì ném ConflictException.
        /// </summary>
        Task<BookingResponse> ConfirmPaidBookingAsync(
            long id,
            string? recipientEmail);

        /// <summary>
        /// Khách huỷ vé chưa trả tiền; vé đã trả tiền giữ ghế và chuyển REFUND_PENDING để Staff xem xét.
        /// Staff/Admin (manager) vẫn huỷ trực tiếp.
        /// </summary>
        Task<BookingResponse> CancelBookingAsync(
            long id,
            bool manager,
            string? reason = null);

        /// <summary>
        /// Suất chiếu bị huỷ: huỷ mọi booking PENDING / CONFIRMED của suất đó. Trả về số booking đã huỷ.
        /// </summary>
        Task<int> CancelBookingsOfShowtimeAsync(long showtimeId, string reason);

        /// <summary>
        /// Khách huỷ thanh toán trên PayOS: huỷ booking còn PENDING để nhả ghế.
        /// </summary>
        Task CancelUnpaidBookingAsync(long id);

        Task ApplyRefundDecisionAsync(long bookingId, bool completed);

        /// <summary>
        /// Đánh dấu EXPIRED cho các booking PENDING đã quá hạn giữ ghế và nhả ghế.
        /// Trả về các booking vừa hết hạn.
        /// </summary>
        Task<List<BookingResponse>> ExpireOverdueBookingsAsync(int batchSize);

        Task<List<long>> GetOccupiedSeatIdsAsync(
            long showtimeId);
    }
}
