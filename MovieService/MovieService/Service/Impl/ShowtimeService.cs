using MovieService.Exception;
using MovieService.Helpers;
using ShowtimeService.DTOs.Request;
using ShowtimeService.DTOs.Response;
using ShowtimeService.Extensions;
using ShowtimeService.Repository.Interface;
using ShowtimeService.Service.Interface;

namespace ShowtimeService.Service.Impl
{
    public class ShowtimeService : IShowtimeService
    {
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

            var hasConflict = await _showtimeRepository
                .HasScheduleConflictAsync(
                    request.RoomId,
                    request.StartTime,
                    request.EndTime);

            if (hasConflict)
            {
                throw new BusinessException(
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

            var hasConflict = await _showtimeRepository
                .HasScheduleConflictAsync(
                    request.RoomId,
                    request.StartTime,
                    request.EndTime,
                    showtimeId);

            if (hasConflict)
            {
                throw new BusinessException(
                    "The room already has a showtime during this period.");
            }

            var updatedShowtime = await _showtimeRepository
                .UpdateShowtimeAsync(
                    showtimeId,
                    request);

            return updatedShowtime?.ToResponse();
        }

        public async Task<bool> DeleteShowtimeAsync(
            long showtimeId)
        {
            if (showtimeId <= 0)
            {
                throw new BusinessException(
                    "Showtime ID must be greater than 0.");
            }

            var existingShowtime = await _showtimeRepository
                .GetShowtimeByIdAsync(showtimeId);

            if (existingShowtime == null)
            {
                throw new NotFoundException(
                    $"Showtime with ID {showtimeId} was not found.");
            }

            return await _showtimeRepository
                .DeleteShowtimeAsync(showtimeId);
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
