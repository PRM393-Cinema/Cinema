using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Configuration;
using BookingService.Helpers;
using BookingService.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BookingService.Controllers
{
    [ApiController]
    [Route("api/v1/payments")]
    [Authorize(Policy = AuthorizationPolicies.AnyRole)]
    public sealed class PaymentController : ControllerBase
    {
        private readonly IPaymentService _paymentService;

        public PaymentController(IPaymentService paymentService)
        {
            _paymentService = paymentService;
        }

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<PagedResult<PaymentResponse>>> GetAll(
            [FromQuery] int page = 1,
            [FromQuery] int size = 10,
            [FromQuery] string sortBy = "createdAt",
            [FromQuery] string sortDir = "desc")
        {
            var result = await _paymentService.GetAllPaymentsAsync(
                page, size, sortBy, sortDir);

            return Ok(result);
        }

        [HttpGet("{id:long}")]
        public async Task<ActionResult<PaymentResponse>> GetById(long id)
        {
            var result = await _paymentService.GetPaymentByIdAsync(id);

            if (!User.IsStaffOrAdmin() && result.UserId != User.GetCurrentUserId())
            {
                return Forbid();
            }

            return Ok(result);
        }

        [HttpGet("user/{userId:long}")]
        public async Task<ActionResult<PagedResult<PaymentResponse>>> GetByUser(
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

            return Ok(await _paymentService.GetPaymentsByUserAsync(
                userId, page, size, sortBy, sortDir));
        }

        [HttpGet("booking/{bookingId:long}")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<PagedResult<PaymentResponse>>> GetByBooking(
            long bookingId,
            [FromQuery] int page = 1,
            [FromQuery] int size = 10,
            [FromQuery] string sortBy = "createdAt",
            [FromQuery] string sortDir = "desc")
        {
            return Ok(await _paymentService.GetPaymentsByBookingAsync(
                bookingId, page, size, sortBy, sortDir));
        }

        [HttpPost]
        public async Task<ActionResult<PaymentResponse>> Create(
            [FromBody] PaymentRequest request)
        {
            if (!User.IsStaffOrAdmin())
            {
                request.UserId = User.GetCurrentUserId();
            }

            return Ok(await _paymentService.CreatePaymentAsync(request));
        }

        [HttpPost("payos/checkout")]
        public async Task<ActionResult<PayOsCheckoutResponse>> CreatePayOsCheckout(
            [FromBody] PayOsCreateRequest request)
        {
            if (!User.IsStaffOrAdmin())
            {
                request.UserId = User.GetCurrentUserId();
            }

            var result = await _paymentService.CreatePayOsPaymentAsync(request);
            return Ok(result);
        }

        // Khách gọi sau khi thanh toán xong trên trang PayOS. PayOS báo đã nhận tiền
        // thì booking được xác nhận tự động và email vé được gửi đi.
        [HttpPost("payos/{orderCode:long}/verify")]
        public async Task<ActionResult<PaymentResponse>> VerifyPayOs(
            long orderCode,
            [FromQuery] string? recipientEmail = null)
        {
            var payment = await _paymentService.GetPaymentByOrderCodeAsync(orderCode);
            var isOwner = payment.UserId == User.GetCurrentUserId();

            if (!isOwner && !User.IsStaffOrAdmin())
            {
                return Forbid();
            }

            // Không truyền email thì gửi vé về email trong token của chính khách
            if (string.IsNullOrWhiteSpace(recipientEmail) && isOwner)
            {
                recipientEmail = User.GetEmail();
            }

            return Ok(await _paymentService.VerifyPayOsPaymentAsync(
                orderCode, recipientEmail));
        }

        [HttpPost("{id:long}/process")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<PaymentResponse>> Process(
            long id,
            [FromQuery] string? recipientEmail = null)
        {
            return Ok(await _paymentService.ProcessPaymentAsync(id, recipientEmail));
        }

        [HttpPost("{id:long}/refund")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<PaymentResponse>> Refund(
            long id,
            [FromQuery] string fallbackRecipientEmail = "")
        {
            return Ok(await _paymentService.RefundPaymentAsync(
                id, fallbackRecipientEmail));
        }

    }
}