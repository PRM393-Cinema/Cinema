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

        [HttpGet]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
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
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<NotificationResponse>> GetById(long id)
        {
            return Ok(await _notificationService.GetNotificationByIdAsync(id));
        }

        [HttpGet("user/{userId:long}")]
        public async Task<ActionResult<PagedResult<NotificationResponse>>> GetByUser(
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

        [HttpDelete("{id:long}")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<IActionResult> Delete(long id)
        {
            await _notificationService.DeleteNotificationAsync(id);
            return NoContent();
        }

    }
}