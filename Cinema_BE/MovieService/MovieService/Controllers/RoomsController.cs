using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MovieService.Configuration;
using MovieService.Helpers;
using ShowtimeService.DTOs.Request;
using ShowtimeService.DTOs.Response;
using ShowtimeService.Service.Interface;

namespace MovieService.Controllers
{
    [ApiController]
    [Route("api/rooms")]
    [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
    public class RoomsController : ControllerBase
    {
        private readonly IRoomService _roomService;

        public RoomsController(IRoomService roomService)
        {
            _roomService = roomService;
        }

        // GET: api/rooms
        [HttpGet]
        public async Task<ActionResult<PagedResult<RoomResponse>>> GetAllRooms(
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] string sortBy = "name",
            [FromQuery] string sortDir = "asc")
        {
            var result = await _roomService.GetAllRoomsAsync(
                pageNumber,
                pageSize,
                sortBy,
                sortDir);

            return Ok(result);
        }

        // GET: api/rooms/{roomId}
        [HttpGet("{roomId:long}")]
        public async Task<ActionResult<RoomResponse>> GetRoomById(
            long roomId)
        {
            var result = await _roomService
                .GetRoomByIdAsync(roomId);

            return Ok(result);
        }

        // POST: api/rooms
        [HttpPost]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public async Task<ActionResult<RoomResponse>> CreateRoom(
            [FromBody] RoomRequest request)
        {
            var result = await _roomService
                .CreateRoomAsync(request);

            return CreatedAtAction(
                nameof(GetRoomById),
                new { roomId = result.Id },
                result);
        }

        // PUT: api/rooms/{roomId}
        [HttpPut("{roomId:long}")]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public async Task<ActionResult<RoomResponse>> UpdateRoom(
            long roomId,
            [FromBody] RoomRequest request)
        {
            var result = await _roomService
                .UpdateRoomAsync(roomId, request);

            return Ok(result);
        }

        // DELETE: api/rooms/{roomId}
        [HttpDelete("{roomId:long}")]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public async Task<IActionResult> DeleteRoom(
            long roomId)
        {
            await _roomService.DeleteRoomAsync(roomId);

            return NoContent();
        }

        // GET: api/rooms/search
        [HttpGet("search")]
        public async Task<ActionResult<PagedResult<RoomResponse>>> SearchRooms(
            [FromQuery] string keyword,
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] string sortBy = "name",
            [FromQuery] string sortDir = "asc")
        {
            var result = await _roomService.SearchRoomsAsync(
                keyword,
                pageNumber,
                pageSize,
                sortBy,
                sortDir);

            return Ok(result);
        }
    }
}
