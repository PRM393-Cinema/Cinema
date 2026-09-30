using ShowtimeService.DTOs.Response;
using MovieService.Helpers;
using ShowtimeService.Models;

namespace ShowtimeService.Extensions
{
    public static class SeatMapping
    {
        public static SeatResponse ToResponse(this Seat seat)
        {
            return new SeatResponse
            {
                Id = seat.Id,
                RoomId = seat.RoomId,
                SeatRow = seat.SeatRow,
                SeatNumber = seat.SeatNumber,
                SeatType = seat.SeatType
            };
        }

        public static PagedResult<SeatResponse> ToPagedResult(
            this PagedList<Seat> seats)
        {
            return new PagedResult<SeatResponse>
            {
                Items = seats.Select(s => s.ToResponse()).ToList(),
                PageNumber = seats.PageNumber,
                PageSize = seats.PageSize,
                TotalPages = seats.TotalPages,
                TotalCount = seats.TotalCount
            };
        }
    }
}
