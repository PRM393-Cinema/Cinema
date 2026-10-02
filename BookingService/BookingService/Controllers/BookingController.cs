using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Helpers;
using BookingService.Configuration;
using BookingService.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;

namespace BookingService.Controllers
{
    [ApiController]
    [Route("api/v1/bookings")]
    [Authorize(Policy = AuthorizationPolicies.AnyRole)]
    public class BookingController : ControllerBase
    {
        private readonly IBookingService _bookingService;

        public BookingController(IBookingService bookingService)
        {
            _bookingService = bookingService;
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<PagedResult<BookingResponse>>> GetAll(
            [FromQuery] int page = 1,
            [FromQuery] int size = 10,
            [FromQuery] string sortBy = "createdAt",
            [FromQuery] string sortDir = "desc")
        {
            var result = await _bookingService.GetAllBookingsAsync(
                page, size, sortBy, sortDir);

            return Ok(result);
        }

        [HttpGet("{id:long}")]
        public async Task<ActionResult<BookingResponse>> GetById(long id)
        {
            var result = await _bookingService.GetBookingByIdAsync(id);

            if (!User.IsStaffOrAdmin() && result.UserId != User.GetCurrentUserId())
            {
                return Forbid();
            }

            return Ok(result);
        }

        [HttpGet("user/{userId:long}")]
        public async Task<ActionResult<PagedResult<BookingResponse>>> GetByUser(
            long userId,
            [FromQuery] int page = 1,
            [FromQuery] int size = 10,
            [FromQuery] string sortBy = "createdAt",
            [FromQuery] string sortDir = "desc")
        {
            if (!User.IsStaffOrAdmin() && userId != User.GetCurrentUserId())
            {
                return Forbid();
            }

            var result = await _bookingService.GetBookingsByUserAsync(
                userId, page, size, sortBy, sortDir);

            return Ok(result);
        }

        [HttpGet("status/{status}")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<PagedResult<BookingResponse>>> GetByStatus(
            string status,
            [FromQuery] int page = 1,
            [FromQuery] int size = 10,
            [FromQuery] string sortBy = "createdAt",
            [FromQuery] string sortDir = "desc")
        {
            var result = await _bookingService.GetBookingsByStatusAsync(
                status, page, size, sortBy, sortDir);

            return Ok(result);
        }

        [HttpGet("date-range")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<PagedResult<BookingResponse>>> GetByDateRange(
            [FromQuery] DateTime start,
            [FromQuery] DateTime end,
            [FromQuery] int page = 1,
            [FromQuery] int size = 10,
            [FromQuery] string sortBy = "createdAt",
            [FromQuery] string sortDir = "desc")
        {
            var result = await _bookingService.GetBookingsByDateRangeAsync(
                start, end, page, size, sortBy, sortDir);

            return Ok(result);
        }

        [HttpGet("showtime/{showtimeId:long}/occupied-seats")]
        public async Task<ActionResult<List<long>>> GetOccupiedSeatIds(
            long showtimeId)
        {
            var result = await _bookingService
                .GetOccupiedSeatIdsAsync(showtimeId);

            return Ok(result);
        }

        [HttpPost]
        public async Task<ActionResult<BookingResponse>> Create(
            [FromBody] BookingRequest request)
        {
            // Khách tự đặt: user và email nhận vé lấy từ token. Staff đặt hộ thì gửi userId + email của khách
            if (!User.IsStaffOrAdmin())
            {
                request.UserId = User.GetCurrentUserId();
                request.CustomerEmail = User.GetEmail();
            }

            var result = await _bookingService.CreateBookingAsync(request);

            return CreatedAtAction(
                nameof(GetById),
                new { id = result.Id },
                result);
        }

        // Xác nhận tay tại quầy (vd: khách trả tiền mặt): chỉ Staff/Admin.
        // Khách thanh toán PayOS thì booking được xác nhận tự động khi PayOS gọi webhook
        // hoặc khi app xác minh thanh toán (POST /api/v1/payments/payos/{orderCode}/verify).
        // Không truyền recipientEmail thì gửi vé về email lưu trên booking.
        [HttpPost("{id:long}/confirm")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<BookingResponse>> Confirm(
            long id,
            [FromQuery] string paymentMethod,
            [FromQuery] string? recipientEmail = null)
        {
            if (string.IsNullOrWhiteSpace(paymentMethod))
            {
                return BadRequest(
                    "Payment method is required.");
            }

            var result = await _bookingService.ConfirmBookingAsync(
                id, paymentMethod, recipientEmail);

            return Ok(result);
        }

        // Khách: huỷ booking chưa thanh toán, hoặc booking đã thanh toán khi còn ít nhất 2 giờ trước giờ chiếu
        // (hoàn 100%). Staff/Admin huỷ được mọi lúc. Đã thanh toán thì yêu cầu hoàn tiền được tạo tự động.
        [HttpPost("{id:long}/cancel")]
        [Authorize(Policy = AuthorizationPolicies.UserOrStaff)]
        public async Task<ActionResult<BookingResponse>> Cancel(
            long id,
            [FromQuery] string? reason = null)
        {
            var existingBooking = await _bookingService.GetBookingByIdAsync(id);
            var manager = User.IsStaffOrAdmin();

            if (!manager && existingBooking.UserId != User.GetCurrentUserId())
            {
                return Forbid();
            }

            var result = await _bookingService.CancelBookingAsync(
                id, manager, reason);

            return Ok(result);
        }

    }
}
