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
            string recipientEmail);

        Task<BookingResponse> CancelBookingAsync(
            long id,
            bool manager);

        /// <summary>
        /// Đánh dấu EXPIRED cho các booking PENDING
        /// đã quá giờ chiếu và chưa được xác nhận tại rạp.
        /// </summary>
        Task ExpirePastShowtimeBookingsAsync();

        Task<List<long>> GetOccupiedSeatIdsAsync(
            long showtimeId);
    }
}
