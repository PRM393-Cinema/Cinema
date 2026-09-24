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

        public ShowtimeService(
            IShowtimeRepository showtimeRepository)
        {
            _showtimeRepository = showtimeRepository;
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
