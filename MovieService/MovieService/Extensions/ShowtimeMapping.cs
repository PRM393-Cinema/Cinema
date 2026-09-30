using ShowtimeService.DTOs.Response;
using MovieService.Helpers;
using ShowtimeService.Models;

namespace ShowtimeService.Extensions
{
    public static class ShowtimeMapping
    {
        public static ShowtimeResponse ToResponse(this Showtime showtime)
        {
            return new ShowtimeResponse
            {
                Id = showtime.Id,
                MovieId = showtime.MovieId,
                RoomId = showtime.RoomId,
                StartTime = showtime.StartTime,
                EndTime = showtime.EndTime,
                Price = showtime.Price,
                Status = showtime.Status
            };
        }

        public static PagedResult<ShowtimeResponse> ToPagedResult(
            this PagedList<Showtime> showtimes)
        {
            return new PagedResult<ShowtimeResponse>
            {
                Items = showtimes.Select(s => s.ToResponse()).ToList(),
                PageNumber = showtimes.PageNumber,
                PageSize = showtimes.PageSize,
                TotalPages = showtimes.TotalPages,
                TotalCount = showtimes.TotalCount
            };
        }
    }
}
