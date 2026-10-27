using BookingService.Configuration;
using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Helpers;
using BookingService.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BookingService.Controllers
{
    // Menu bắp nước bán kèm vé: ai cũng xem được món đang bán; Admin thêm / sửa / ngừng bán
    [ApiController]
    [Route("api/v1/concessions")]
    public class ConcessionController : ControllerBase
    {
        private readonly IConcessionService _concessionService;

        public ConcessionController(IConcessionService concessionService)
        {
            _concessionService = concessionService;
        }

        // includeInactive=true (Staff/Admin): cả món đã ngừng bán
        [HttpGet]
        [AllowAnonymous]
        public async Task<ActionResult<List<ConcessionItemResponse>>> GetAll(
            [FromQuery] bool includeInactive = false)
        {
            var manager = User.Identity?.IsAuthenticated == true && User.IsStaffOrAdmin();
            return Ok(await _concessionService.GetItemsAsync(includeInactive && manager));
        }

        [HttpPost]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public async Task<ActionResult<ConcessionItemResponse>> Create(
            [FromBody] ConcessionItemRequest request)
        {
            return Ok(await _concessionService.CreateAsync(request));
        }

        [HttpPut("{id:long}")]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public async Task<ActionResult<ConcessionItemResponse>> Update(
            long id,
            [FromBody] ConcessionItemRequest request)
        {
            return Ok(await _concessionService.UpdateAsync(id, request));
        }
    }
}
