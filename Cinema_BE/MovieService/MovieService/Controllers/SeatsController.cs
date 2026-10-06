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
    [Route("api/seats")]
    public class SeatsController : ControllerBase
    {
        private readonly ISeatService _seatService;

        public SeatsController(ISeatService seatService)
        {
            _seatService = seatService;
        }

        // GET: api/seats/{seatId}
        [HttpGet("{seatId:long}")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<SeatResponse>> GetSeatById(
            long seatId)
        {
            var result = await _seatService
                .GetSeatByIdAsync(seatId);

            return Ok(result);
        }

        // GET: api/seats/room/{roomId}
        // Sơ đồ ghế của phòng: trả toàn bộ ghế, sắp theo hàng rồi số ghế
        [HttpGet("room/{roomId:long}")]
        [Authorize]
        public async Task<ActionResult<List<SeatResponse>>> GetSeatsByRoom(
            long roomId)
        {
            var result = await _seatService
                .GetSeatsByRoomAsync(roomId);

            return Ok(result);
        }

        // POST: api/seats/generate
        [HttpPost("generate")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<SeatResponse>> GenerateSeats(
            [FromBody] GenerateSeatRequest request)
        {
            var result = await _seatService
                .GenerateSeatAsync(request);

            return Ok(result);
        }

        // PUT: api/seats/{seatId}/type
        [HttpPut("{seatId:long}/type")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<SeatResponse>> UpdateSeatType(
            long seatId,
            [FromBody] UpdateSeatTypeRequest request)
        {
            var result = await _seatService
                .UpdateSeatTypeAsync(seatId, request);

            return Ok(result);
        }

        // DELETE: api/seats/{seatId}
        [HttpDelete("{seatId:long}")]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public async Task<IActionResult> DeleteSeat(
            long seatId)
        {
            await _seatService.DeleteSeatAsync(seatId);

            return NoContent();
        }
    }
}
