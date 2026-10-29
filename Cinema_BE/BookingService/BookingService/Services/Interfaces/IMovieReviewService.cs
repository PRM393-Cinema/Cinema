using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;

namespace BookingService.Services.Interfaces
{
    public interface IMovieReviewService
    {
        // viewerId: người đang xem (đánh dấu Mine), null khi chưa đăng nhập
        Task<MovieReviewsResponse> GetForMovieAsync(long movieId, long? viewerId, int page, int size);

        Task<List<MovieReviewResponse>> GetMineAsync(long userId);

        // Vé của khách: đã được đánh giá chưa và đánh giá hiện có cho phim của vé
        Task<BookingReviewResponse> GetForBookingAsync(long userId, long bookingId);

        // Vé phải thuộc khách và đã check-in
        Task<MovieReviewResponse> SaveAsync(long userId, string reviewerName, MovieReviewRequest request);

        // Chủ đánh giá hoặc Admin; false khi không có quyền
        Task<bool> DeleteAsync(long id, long userId, bool admin);
    }
}
