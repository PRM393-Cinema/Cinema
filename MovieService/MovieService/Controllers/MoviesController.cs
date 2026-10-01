using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MovieService.Configuration;
using MovieService.DTOs.Request;
using MovieService.DTOs.Response;
using MovieService.Helpers;
using MovieService.Service.Interface;

namespace MovieService.Controllers
{
    [ApiController]
    [Route("api/v1/movies")]
    public class MoviesController : ControllerBase
    {
        private readonly IMovieService _movieService;

        public MoviesController(IMovieService movieService)
        {
            _movieService = movieService;
        }

        [HttpGet]
        [AllowAnonymous]
        public async Task<ActionResult<PagedResult<MovieResponse>>> GetAllMovies(
            [FromQuery] int page = 1,
            [FromQuery] int size = 10,
            [FromQuery] string sortBy = "createdAt",
            [FromQuery] string sortDir = "desc")
        {
            var result = await _movieService.GetAllMoviesAsync(page, size, sortBy, sortDir);
            return Ok(result);
        }

        [HttpGet("{id:long}")]
        [AllowAnonymous]
        public async Task<ActionResult<MovieResponse>> GetMovieById(long id)
        {
            var movie = await _movieService.GetMovieByIdAsync(id);
            return Ok(movie);
        }

        [HttpGet("status/{status}")]
        [AllowAnonymous]
        public async Task<ActionResult<PagedResult<MovieResponse>>> GetByStatus(
            string status,
            [FromQuery] int page = 1,
            [FromQuery] int size = 10,
            [FromQuery] string sortBy = "createdAt",
            [FromQuery] string sortDir = "desc")
        {
            var result = await _movieService.GetByStatusAsync(status, page, size, sortBy, sortDir);
            return Ok(result);
        }

        [HttpGet("search")]
        [AllowAnonymous]
        public async Task<ActionResult<PagedResult<MovieResponse>>> SearchMovies(
            [FromQuery] string keyword,
            [FromQuery] int page = 1,
            [FromQuery] int size = 10,
            [FromQuery] string sortBy = "createdAt",
            [FromQuery] string sortDir = "desc")
        {
            var result = await _movieService.SearchMoviesAsync(keyword, page, size, sortBy, sortDir);
            return Ok(result);
        }

        [HttpPost]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public async Task<ActionResult<MovieResponse>> CreateMovie([FromBody] MovieRequest request)
        {
            var result = await _movieService.CreateMovieAsync(request);

            return CreatedAtAction(nameof(GetMovieById), new { id = result.Id }, result);
        }

        [HttpPut("{id:long}")]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public async Task<ActionResult<MovieResponse>> UpdateMovie(long id, [FromBody] MovieRequest request)
        {
            var result = await _movieService.UpdateMovieAsync(id, request);
            return Ok(result);
        }

        [HttpDelete("{id:long}")]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public async Task<IActionResult> DeleteMovie(long id)
        {
            await _movieService.DeleteMovieAsync(id);
            return NoContent(); // HTTP 204
        }
    }
}
