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
    [Route("api/v1/notifications")]
    [Authorize(Policy = AuthorizationPolicies.AnyRole)]
    public sealed class NotificationController : ControllerBase
    {
        private readonly INotificationService _notificationService;

        public NotificationController(INotificationService notificationService)
        {
            _notificationService = notificationService;
        }

        // Xem thông báo của mọi người: chỉ Admin. Customer / Staff chỉ xem của chính mình (ma trận quyền SRS §9)
        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public async Task<ActionResult<PagedResult<NotificationResponse>>> GetAll(
            [FromQuery] int page = 1,
            [FromQuery] int size = 10,
            [FromQuery] string sortBy = "createdAt",
            [FromQuery] string sortDir = "desc")
        {
            return Ok(await _notificationService.GetAllNotificationsAsync(
                page, size, sortBy, sortDir));
        }

        [HttpGet("{id:long}")]
        public async Task<ActionResult<NotificationResponse>> GetById(long id)
        {
            var result = await _notificationService.GetNotificationByIdAsync(id);

            if (!User.IsAdmin() && result.UserId != User.GetCurrentUserId())
            {
                return Forbid();
            }

            return Ok(result);
        }

        [HttpGet("user/{userId:long}")]
        public async Task<ActionResult<PagedResult<NotificationResponse>>> GetByUser(
            long userId,
            [FromQuery] int page = 1,
            [FromQuery] int size = 10,
            [FromQuery] string sortBy = "createdAt",
            [FromQuery] string sortDir = "desc")
        {
            if (!User.IsAdmin() && userId != User.GetCurrentUserId())
            {
                return Forbid();
            }

            return Ok(await _notificationService.GetNotificationsByUserAsync(
                userId, page, size, sortBy, sortDir));
        }

        [HttpPost]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<NotificationResponse>> Create(
            [FromBody] NotificationRequest request)
        {
            return Ok(await _notificationService.CreateNotificationAsync(request));
        }

        [HttpPost("{id:long}/send")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<NotificationResponse>> Send(long id)
        {
            return Ok(await _notificationService.SendNotificationAsync(id));
        }

        // Người nhận tự xoá thông báo của mình; Admin xoá được mọi thông báo
        [HttpDelete("{id:long}")]
        public async Task<IActionResult> Delete(long id)
        {
            var notification = await _notificationService.GetNotificationByIdAsync(id);

            if (!User.IsAdmin() && notification.UserId != User.GetCurrentUserId())
            {
                return Forbid();
            }

            await _notificationService.DeleteNotificationAsync(id);
            return NoContent();
        }

    }
}