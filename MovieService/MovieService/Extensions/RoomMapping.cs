using MovieService.Helpers;
using ShowtimeService.DTOs.Response;
using ShowtimeService.Models;

namespace ShowtimeService.Extensions
{
    public static class RoomMapping
    {
        public static RoomResponse ToResponse(this Room room)
        {
            return new RoomResponse
            {
                Id = room.Id,
                Name = room.Name,
                TotalSeats = room.TotalSeats
            };
        }

        public static PagedResult<RoomResponse> ToPagedResult(
            this PagedList<Room> rooms)
        {
            return new PagedResult<RoomResponse>
            {
                Items = rooms.Select(r => r.ToResponse()).ToList(),
                PageNumber = rooms.PageNumber,
                PageSize = rooms.PageSize,
                TotalPages = rooms.TotalPages,
                TotalCount = rooms.TotalCount
            };
        }
    }
}
