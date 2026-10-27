using BookingService.Configuration;
using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Helpers;
using BookingService.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BookingService.Controllers
{
    // Điểm thành viên: khách xem thẻ của mình; quầy xem thẻ của khách; Admin chỉnh điểm
    [ApiController]
    [Route("api/v1/loyalty")]
    [Authorize]
    public class LoyaltyController : ControllerBase
    {
        private readonly ILoyaltyService _loyaltyService;

        public LoyaltyController(ILoyaltyService loyaltyService)
        {
            _loyaltyService = loyaltyService;
        }

        [HttpGet("me")]
        public async Task<ActionResult<LoyaltyResponse>> GetMine()
        {
            return Ok(await _loyaltyService.GetAsync(User.GetCurrentUserId()));
        }

        [HttpGet("users/{userId:long}")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<LoyaltyResponse>> GetOfUser(long userId)
        {
            return Ok(await _loyaltyService.GetAsync(userId));
        }

        // GET /api/v1/loyalty/accounts?userIds=1,2,3  (tối đa 100 khách)
        [HttpGet("accounts")]
        [Authorize(Policy = AuthorizationPolicies.StaffOrAdmin)]
        public async Task<ActionResult<List<LoyaltyAccountResponse>>> GetAccounts([FromQuery] string? userIds)
        {
            var ids = (userIds ?? string.Empty)
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(text => long.TryParse(text, out var id) ? id : 0)
                .Where(id => id > 0);
            return Ok(await _loyaltyService.GetAccountsAsync(ids));
        }

        [HttpPost("users/{userId:long}/adjust")]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public async Task<ActionResult<LoyaltyResponse>> Adjust(long userId, [FromBody] LoyaltyAdjustRequest request)
        {
            return Ok(await _loyaltyService.AdjustAsync(
                userId,
                request.Points!.Value,
                request.Note!,
                User.GetCurrentUserId()));
        }
    }
}
