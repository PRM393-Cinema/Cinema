using Microsoft.AspNetCore.Mvc;
using MovieService.Helpers;
using ShowtimeService.DTOs.Request;
using ShowtimeService.DTOs.Response;
using ShowtimeService.Service.Interface;

namespace ShowtimeService.Controllers
{
    [ApiController]
    [Route("api/showtimes")]
    public class ShowtimesController : ControllerBase
    {
        private readonly IShowtimeService _showtimeService;

        public ShowtimesController(IShowtimeService showtimeService)
        {
            _showtimeService = showtimeService;
        }

        // GET: api/showtimes
        [HttpGet]
        public async Task<ActionResult<PagedResult<ShowtimeResponse>>> GetAllShowtimes(
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] string sortBy = "startTime",
            [FromQuery] string sortDir = "asc")
        {
            var result = await _showtimeService.GetAllShowtimesAsync(
                pageNumber,
                pageSize,
                sortBy,
                sortDir);

            return Ok(result);
        }

        // GET: api/showtimes/{showtimeId}
        [HttpGet("{showtimeId:long}")]
        public async Task<ActionResult<ShowtimeResponse>> GetShowtimeById(
            long showtimeId)
        {
            var result = await _showtimeService
                .GetShowtimeByIdAsync(showtimeId);

            return Ok(result);
        }

        // POST: api/showtimes
        [HttpPost]
        public async Task<ActionResult<ShowtimeResponse>> CreateShowtime(
            [FromBody] ShowtimeRequest request)
        {
            var result = await _showtimeService
                .CreateShowtimeAsync(request);

            return CreatedAtAction(
                nameof(GetShowtimeById),
                new { showtimeId = result.Id },
                result);
        }

        // PUT: api/showtimes/{showtimeId}
        [HttpPut("{showtimeId:long}")]
        public async Task<ActionResult<ShowtimeResponse>> UpdateShowtime(
            long showtimeId,
            [FromBody] ShowtimeRequest request)
        {
            var result = await _showtimeService
                .UpdateShowtimeAsync(showtimeId, request);

            return Ok(result);
        }

        // DELETE: api/showtimes/{showtimeId}
        [HttpDelete("{showtimeId:long}")]
        public async Task<IActionResult> DeleteShowtime(
            long showtimeId)
        {
            await _showtimeService.DeleteShowtimeAsync(showtimeId);

            return NoContent();
        }

        // GET: api/showtimes/open
        [HttpGet("open")]
        public async Task<ActionResult<PagedResult<ShowtimeResponse>>> GetOpenShowtimes(
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] string sortBy = "startTime",
            [FromQuery] string sortDir = "asc")
        {
            var result = await _showtimeService.GetOpenShowtimesAsync(
                pageNumber,
                pageSize,
                sortBy,
                sortDir);

            return Ok(result);
        }

        // GET: api/showtimes/movie/{movieId}
        [HttpGet("movie/{movieId:long}")]
        public async Task<ActionResult<PagedResult<ShowtimeResponse>>> GetShowtimesByMovie(
            long movieId,
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] string sortBy = "startTime",
            [FromQuery] string sortDir = "asc")
        {
            var result = await _showtimeService.GetShowtimesByMovieAsync(
                movieId,
                pageNumber,
                pageSize,
                sortBy,
                sortDir);

            return Ok(result);
        }

        // GET: api/showtimes/date-range
        [HttpGet("date-range")]
        public async Task<ActionResult<PagedResult<ShowtimeResponse>>> GetShowtimesByDateRange(
            [FromQuery] DateTime start,
            [FromQuery] DateTime end,
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] string sortBy = "startTime",
            [FromQuery] string sortDir = "asc")
        {
            var result = await _showtimeService
                .GetShowtimesByDateRangeAsync(
                    start,
                    end,
                    pageNumber,
                    pageSize,
                    sortBy,
                    sortDir);

            return Ok(result);
        }
    }
}
