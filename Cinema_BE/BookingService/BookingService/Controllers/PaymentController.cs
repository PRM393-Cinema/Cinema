using System.Text.Json;
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
        private readonly IBookingService _bookingService;
        private readonly IRefundService _refundService;

        public PaymentController(
            IPaymentService paymentService,
            IBookingService bookingService,
            IRefundService refundService)
        {
            _paymentService = paymentService;
            _bookingService = bookingService;
            _refundService = refundService;
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

        // Khách xem được payment của booking của chính mình (FR-PAY-05)
        [HttpGet("booking/{bookingId:long}")]
        public async Task<ActionResult<PagedResult<PaymentResponse>>> GetByBooking(
            long bookingId,
            [FromQuery] int page = 1,
            [FromQuery] int size = 10,
            [FromQuery] string sortBy = "createdAt",
            [FromQuery] string sortDir = "desc")
        {
            if (!User.IsStaffOrAdmin())
            {
                var booking = await _bookingService.GetBookingByIdAsync(bookingId);

                if (booking.UserId != User.GetCurrentUserId())
                {
                    return Forbid();
                }
            }

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

        // PayOS gọi về khi khách thanh toán xong (không có JWT, xác thực bằng chữ ký HMAC trong body).
        // Đăng ký URL này trong trang quản lý PayOS: https://<domain>/api/v1/payments/payos/webhook
        [HttpPost("payos/webhook")]
        [AllowAnonymous]
        public async Task<IActionResult> PayOsWebhook([FromBody] JsonElement body)
        {
            var result = await _paymentService.HandlePayOsWebhookAsync(body);

            if (!result.SignatureValid)
            {
                return BadRequest(new { success = false, message = result.Message });
            }

            return Ok(new { success = true, message = result.Message });
        }

        [HttpPost("{id:long}/process")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<PaymentResponse>> Process(
            long id,
            [FromQuery] string? recipientEmail = null)
        {
            return Ok(await _paymentService.ProcessPaymentAsync(id, recipientEmail));
        }

        // ----- Hoàn tiền (FR-PAY-06) -----

        // Staff/Admin hoàn tiền một payment đã thanh toán: booking còn hiệu lực thì huỷ luôn, tạo yêu cầu hoàn 100%
        [HttpPost("{id:long}/refund")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<RefundResponse>> Refund(
            long id,
            [FromQuery] string? reason = null)
        {
            return Ok(await _paymentService.RefundPaymentAsync(id, reason));
        }

        // Yêu cầu hoàn tiền của một payment (chủ payment hoặc Staff/Admin)
        [HttpGet("{id:long}/refund")]
        public async Task<ActionResult<RefundResponse>> GetRefundOfPayment(long id)
        {
            var payment = await _paymentService.GetPaymentByIdAsync(id);

            if (!User.IsStaffOrAdmin() && payment.UserId != User.GetCurrentUserId())
            {
                return Forbid();
            }

            return Ok(await _refundService.GetRefundByPaymentIdAsync(id));
        }

        // Danh sách yêu cầu hoàn tiền, lọc theo status (PENDING = cần chuyển khoản trả khách)
        [HttpGet("refunds")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<PagedResult<RefundResponse>>> GetRefunds(
            [FromQuery] string? status = null,
            [FromQuery] int page = 1,
            [FromQuery] int size = 10)
        {
            return Ok(await _refundService.GetRefundsAsync(status, page, size));
        }

        [HttpGet("refunds/{refundId:long}")]
        public async Task<ActionResult<RefundResponse>> GetRefund(long refundId)
        {
            var refund = await _refundService.GetRefundByIdAsync(refundId);

            if (!User.IsStaffOrAdmin() && refund.UserId != User.GetCurrentUserId())
            {
                return Forbid();
            }

            return Ok(refund);
        }

        // Staff đã chuyển khoản trả khách: ghi mã giao dịch, payment -> REFUNDED, khách nhận email
        [HttpPost("refunds/{refundId:long}/complete")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<RefundResponse>> CompleteRefund(
            long refundId,
            [FromBody] CompleteRefundRequest request)
        {
            return Ok(await _refundService.CompleteRefundAsync(
                refundId,
                request.TransactionRef!,
                request.Note,
                User.GetCurrentUserId()));
        }

    }
}