using Microsoft.AspNetCore.Mvc;
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
        public async Task<ActionResult<SeatResponse>> GetSeatById(
            long seatId)
        {
            var result = await _seatService
                .GetSeatByIdAsync(seatId);

            return Ok(result);
        }

        // POST: api/seats/generate
        [HttpPost("generate")]
        public async Task<ActionResult<SeatResponse>> GenerateSeats(
            [FromBody] GenerateSeatRequest request)
        {
            var result = await _seatService
                .GenerateSeatAsync(request);

            return Ok(result);
        }

        // PUT: api/seats/{seatId}/type
        [HttpPut("{seatId:long}/type")]
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
        public async Task<IActionResult> DeleteSeat(
            long seatId)
        {
            await _seatService.DeleteSeatAsync(seatId);

            return NoContent();
        }
    }
}
