using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Helpers;
using BookingService.Services.Implementations;
using BookingService.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BookingService.Controllers
{
    // Đánh giá phim: ai cũng xem được; khách đã xem phim (vé đã check-in) mới viết được
    [ApiController]
    [Route("api/v1/reviews")]
    [Authorize]
    public class MovieReviewController : ControllerBase
    {
        private readonly IMovieReviewService _reviewService;

        public MovieReviewController(IMovieReviewService reviewService)
        {
            _reviewService = reviewService;
        }

        // Điểm trung bình, số đánh giá theo mức sao và đánh giá mới nhất trước
        [HttpGet("movie/{movieId:long}")]
        [AllowAnonymous]
        public async Task<ActionResult<MovieReviewsResponse>> GetForMovie(
            long movieId,
            [FromQuery] int page = 1,
            [FromQuery] int size = 10)
        {
            long? viewer = User.Identity?.IsAuthenticated == true ? User.GetCurrentUserId() : null;
            return Ok(await _reviewService.GetForMovieAsync(movieId, viewer, page, size));
        }

        [HttpGet("mine")]
        public async Task<ActionResult<List<MovieReviewResponse>>> GetMine()
        {
            return Ok(await _reviewService.GetMineAsync(User.GetCurrentUserId()));
        }

        // Vé của khách đã được đánh giá chưa (đã check-in) và đánh giá hiện có cho phim của vé
        [HttpGet("booking/{bookingId:long}")]
        public async Task<ActionResult<BookingReviewResponse>> GetForBooking(long bookingId)
        {
            return Ok(await _reviewService.GetForBookingAsync(User.GetCurrentUserId(), bookingId));
        }

        // Tạo hoặc sửa đánh giá phim của vé đã check-in
        [HttpPost]
        public async Task<ActionResult<MovieReviewResponse>> Save([FromBody] MovieReviewRequest request)
        {
            var name = MovieReviewService.DisplayName(User.FindFirst("fullName")?.Value, User.GetEmail());
            return Ok(await _reviewService.SaveAsync(User.GetCurrentUserId(), name, request));
        }

        // Chủ đánh giá xoá đánh giá của mình; Admin xoá đánh giá không phù hợp
        [HttpDelete("{id:long}")]
        public async Task<IActionResult> Delete(long id)
        {
            return await _reviewService.DeleteAsync(id, User.GetCurrentUserId(), User.IsAdmin())
                ? NoContent()
                : Forbid();
        }
    }
}
