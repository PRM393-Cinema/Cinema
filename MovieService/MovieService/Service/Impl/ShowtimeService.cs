using MovieService.Exception;
using MovieService.Helpers;
using ShowtimeService.DTOs.Request;
using ShowtimeService.DTOs.Response;
using ShowtimeService.Extensions;
using ShowtimeService.Models;
using ShowtimeService.Repository.Interface;
using ShowtimeService.Service.Interface;

namespace ShowtimeService.Service.Impl
{
    public class ShowtimeService : IShowtimeService
    {
        // OPEN: đang bán vé. CLOSED: ngừng bán, vé đã bán vẫn giữ. CANCELLED: suất chiếu bị huỷ (không mở lại được)
        private const string Open = "OPEN";
        private const string Closed = "CLOSED";
        private const string Cancelled = "CANCELLED";

        private readonly IShowtimeRepository _showtimeRepository;
        private readonly ISeatRepository _seatRepository;

        public ShowtimeService(
            IShowtimeRepository showtimeRepository,
            ISeatRepository seatRepository)
        {
            _showtimeRepository = showtimeRepository;
            _seatRepository = seatRepository;
        }

        // ======= GET SEATS FOR BOOKING (BookingService gọi sang) =======
        public async Task<List<ShowtimeSeatResponse>> GetSeatsForBookingAsync(
            long showtimeId,
            List<long> seatIds)
        {
            if (seatIds == null || seatIds.Count == 0)
            {
                throw new BusinessException("At least one seat id is required.");
            }

            var showtime = await _showtimeRepository.GetShowtimeByIdAsync(showtimeId)
                ?? throw new NotFoundException($"Showtime with ID {showtimeId} was not found.");

            if (!string.Equals(showtime.Status, "OPEN", StringComparison.OrdinalIgnoreCase))
            {
                throw new BusinessException($"Showtime with ID {showtimeId} is not open for booking.");
            }

            if (showtime.StartTime <= DateTime.Now)
            {
                throw new BusinessException($"Showtime with ID {showtimeId} has already started.");
            }

            var requestedIds = seatIds.Distinct().ToList();
            var seats = await _seatRepository.GetSeatsByIdsAsync(requestedIds);

            var invalidIds = requestedIds
                .Except(seats.Where(s => s.RoomId == showtime.RoomId).Select(s => s.Id))
                .ToList();

            if (invalidIds.Count > 0)
            {
                throw new BusinessException(
                    $"Seat(s) {string.Join(", ", invalidIds)} do not belong to the room of showtime {showtimeId}.");
            }

            // Giá ghế = giá suất chiếu (khớp dữ liệu hiện có: booking_seats.price = showtimes.price).
            return seats
                .OrderBy(s => requestedIds.IndexOf(s.Id))
                .Select(s => new ShowtimeSeatResponse
                {
                    SeatId = s.Id,
                    SeatLabel = $"{s.SeatRow}{s.SeatNumber}",
                    Price = showtime.Price
                })
                .ToList();
        }

        public async Task<PagedResult<ShowtimeResponse>> GetAllShowtimesAsync(
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            var p = PaginationUtils.Normalize(
                pageNumber,
                pageSize,
                sortBy,
                sortDir);

            var showtimes = await _showtimeRepository.GetAllShowtimesAsync(
                p.PageNumber,
                p.PageSize,
                p.SortBy,
                p.SortDir);

            return showtimes.ToPagedResult();
        }

        public async Task<ShowtimeResponse?> GetShowtimeByIdAsync(
            long showtimeId)
        {
            if (showtimeId <= 0)
            {
                throw new BusinessException(
                    "Showtime ID must be greater than 0.");
            }

            var showtime = await _showtimeRepository
                .GetShowtimeByIdAsync(showtimeId);

            if (showtime == null)
            {
                throw new NotFoundException(
                    $"Showtime with ID {showtimeId} was not found.");
            }

            return showtime.ToResponse();
        }

        public async Task<ShowtimeResponse> CreateShowtimeAsync(
            ShowtimeRequest request)
        {
            ValidateShowtimeRequest(request);

            if (request.StartTime >= request.EndTime)
            {
                throw new BusinessException(
                    "Start time must be earlier than end time.");
            }

            request.Status = NormalizeEditableStatus(request.Status) ?? Open;

            var hasConflict = await _showtimeRepository
                .HasScheduleConflictAsync(
                    request.RoomId,
                    request.StartTime,
                    request.EndTime);

            if (hasConflict)
            {
                throw new ConflictException(
                    "The room already has a showtime during this period.");
            }

            var showtime = await _showtimeRepository
                .CreateShowtimeAsync(request);

            return showtime.ToResponse();
        }

        public async Task<ShowtimeResponse?> UpdateShowtimeAsync(
            long showtimeId,
            ShowtimeRequest request)
        {
            if (showtimeId <= 0)
            {
                throw new BusinessException(
                    "Showtime ID must be greater than 0.");
            }

            ValidateShowtimeRequest(request);

            if (request.StartTime >= request.EndTime)
            {
                throw new BusinessException(
                    "Start time must be earlier than end time.");
            }

            var existingShowtime = await _showtimeRepository
                .GetShowtimeByIdAsync(showtimeId);

            if (existingShowtime == null)
            {
                throw new NotFoundException(
                    $"Showtime with ID {showtimeId} was not found.");
            }

            EnsureNotCancelled(existingShowtime.Status, showtimeId);

            // Không gửi status thì giữ nguyên trạng thái hiện tại
            request.Status = NormalizeEditableStatus(request.Status) ?? existingShowtime.Status;

            var hasConflict = await _showtimeRepository
                .HasScheduleConflictAsync(
                    request.RoomId,
                    request.StartTime,
                    request.EndTime,
                    showtimeId);

            if (hasConflict)
            {
                throw new ConflictException(
                    "The room already has a showtime during this period.");
            }

            var updatedShowtime = await _showtimeRepository
                .UpdateShowtimeAsync(
                    showtimeId,
                    request);

            return updatedShowtime?.ToResponse();
        }

        // FR-SHOW-05: huỷ suất chiếu = chuyển sang CANCELLED, không xoá khỏi DB vì booking vẫn trỏ tới suất chiếu này
        public async Task<ShowtimeResponse> CancelShowtimeAsync(
            long showtimeId)
        {
            var existingShowtime = await GetExistingShowtimeAsync(showtimeId);

            EnsureNotCancelled(existingShowtime.Status, showtimeId);

            if (existingShowtime.EndTime <= DateTime.Now)
            {
                throw new ConflictException(
                    $"Showtime with ID {showtimeId} has already ended and cannot be cancelled.");
            }

            var cancelled = await _showtimeRepository
                .UpdateStatusAsync(showtimeId, Cancelled);

            return cancelled!.ToResponse();
        }

        // Đóng / mở bán lại suất chiếu (OPEN <-> CLOSED). Huỷ hẳn thì dùng CancelShowtimeAsync
        public async Task<ShowtimeResponse> UpdateShowtimeStatusAsync(
            long showtimeId,
            string status)
        {
            var normalizedStatus = NormalizeEditableStatus(status)
                ?? throw new BusinessException("Status is required (OPEN or CLOSED).");

            var existingShowtime = await GetExistingShowtimeAsync(showtimeId);

            EnsureNotCancelled(existingShowtime.Status, showtimeId);

            var updated = await _showtimeRepository
                .UpdateStatusAsync(showtimeId, normalizedStatus);

            return updated!.ToResponse();
        }

        public async Task<PagedResult<ShowtimeResponse>> GetOpenShowtimesAsync(
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            var p = PaginationUtils.Normalize(
                pageNumber,
                pageSize,
                sortBy,
                sortDir);

            var showtimes = await _showtimeRepository
                .GetOpenShowtimesAsync(
                    p.PageNumber,
                    p.PageSize,
                    p.SortBy,
                    p.SortDir);

            return showtimes.ToPagedResult();
        }

        public async Task<PagedResult<ShowtimeResponse>> GetShowtimesByMovieAsync(
            long movieId,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            if (movieId <= 0)
            {
                throw new BusinessException(
                    "Movie ID must be greater than 0.");
            }

            var p = PaginationUtils.Normalize(
                pageNumber,
                pageSize,
                sortBy,
                sortDir);

            var showtimes = await _showtimeRepository
                .GetShowtimesByMovieAsync(
                    movieId,
                    p.PageNumber,
                    p.PageSize,
                    p.SortBy,
                    p.SortDir);

            return showtimes.ToPagedResult();
        }

        // FR-SHOW-08: suất chiếu của phim còn đặt vé được (đang mở bán, chưa bắt đầu)
        public async Task<PagedResult<ShowtimeResponse>> GetOpenShowtimesByMovieAsync(
            long movieId,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            if (movieId <= 0)
            {
                throw new BusinessException(
                    "Movie ID must be greater than 0.");
            }

            var p = PaginationUtils.Normalize(
                pageNumber,
                pageSize,
                sortBy,
                sortDir);

            var showtimes = await _showtimeRepository
                .GetOpenShowtimesByMovieAsync(
                    movieId,
                    p.PageNumber,
                    p.PageSize,
                    p.SortBy,
                    p.SortDir);

            return showtimes.ToPagedResult();
        }

        public async Task<PagedResult<ShowtimeResponse>> GetShowtimesByDateRangeAsync(
            DateTime start,
            DateTime end,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            if (start >= end)
            {
                throw new BusinessException(
                    "Start date must be earlier than end date.");
            }

            var p = PaginationUtils.Normalize(
                pageNumber,
                pageSize,
                sortBy,
                sortDir);

            var showtimes = await _showtimeRepository
                .GetShowtimesByDateRangeAsync(
                    start,
                    end,
                    p.PageNumber,
                    p.PageSize,
                    p.SortBy,
                    p.SortDir);

            return showtimes.ToPagedResult();
        }

        private async Task<Showtime> GetExistingShowtimeAsync(long showtimeId)
        {
            if (showtimeId <= 0)
            {
                throw new BusinessException(
                    "Showtime ID must be greater than 0.");
            }

            return await _showtimeRepository.GetShowtimeByIdAsync(showtimeId)
                ?? throw new NotFoundException(
                    $"Showtime with ID {showtimeId} was not found.");
        }

        private static void EnsureNotCancelled(string status, long showtimeId)
        {
            if (string.Equals(status, Cancelled, StringComparison.OrdinalIgnoreCase))
            {
                throw new ConflictException(
                    $"Showtime with ID {showtimeId} has been cancelled.");
            }
        }

        // Trạng thái sửa tay được: OPEN / CLOSED. Rỗng -> null (người gọi tự chọn mặc định)
        private static string? NormalizeEditableStatus(string? status)
        {
            if (string.IsNullOrWhiteSpace(status))
            {
                return null;
            }

            var normalized = status.Trim().ToUpperInvariant();

            return normalized switch
            {
                Open or Closed => normalized,
                Cancelled => throw new BusinessException(
                    "Use DELETE /api/showtimes/{id} to cancel a showtime."),
                _ => throw new BusinessException(
                    "Status must be OPEN or CLOSED.")
            };
        }

        private static void ValidateShowtimeRequest(
            ShowtimeRequest request)
        {
            if (request == null)
            {
                throw new BusinessException(
                    "Showtime request is required.");
            }

            if (request.MovieId <= 0)
            {
                throw new BusinessException(
                    "Movie ID must be greater than 0.");
            }

            if (request.RoomId <= 0)
            {
                throw new BusinessException(
                    "Room ID must be greater than 0.");
            }

            if (request.StartTime == default)
            {
                throw new BusinessException(
                    "Start time is required.");
            }

            if (request.EndTime == default)
            {
                throw new BusinessException(
                    "End time is required.");
            }
        }
    }
}
