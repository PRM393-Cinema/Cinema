namespace BookingService.Clients.Interfaces
{
    public interface IShowtimeClient
    {
            Task<List<ShowtimeSeatInfo>> GetSeatsAsync(
                long showtimeId,
                List<long> seatIds);

            // Giờ chiếu thật của suất chiếu (không tin giờ chiếu do app gửi lên)
            Task<ShowtimeInfo> GetShowtimeAsync(long showtimeId);

            // Tên phim để ghi vào booking / email. Lỗi thì trả null, không chặn việc đặt vé
            Task<string?> GetMovieTitleAsync(long movieId);
    }
}
