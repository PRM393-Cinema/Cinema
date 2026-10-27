using BookingService.Configuration;
using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Helpers;
using BookingService.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BookingService.Controllers
{
    // Khuyến mãi giảm tiền vé: khách xem khuyến mãi tự áp dụng và thử mã voucher; Admin quản lý
    [ApiController]
    [Route("api/v1/promotions")]
    public class PromotionController : ControllerBase
    {
        private readonly IPromotionService _promotionService;

        public PromotionController(IPromotionService promotionService)
        {
            _promotionService = promotionService;
        }

        // all=true (Admin): mọi khuyến mãi, kể cả mã voucher và đã kết thúc
        [HttpGet]
        [AllowAnonymous]
        public async Task<ActionResult<List<PromotionResponse>>> GetAll([FromQuery] bool all = false)
        {
            var admin = User.Identity?.IsAuthenticated == true && User.IsAdmin();
            return Ok(await _promotionService.GetPromotionsAsync(all && admin));
        }

        // Số tiền được giảm cho các vé đang chọn (mã sai / không đủ điều kiện thì 400)
        [HttpPost("quote")]
        [Authorize]
        public async Task<ActionResult<PromotionQuoteResponse>> Quote([FromBody] PromotionQuoteRequest request)
        {
            return Ok(await _promotionService.QuoteAsync(request));
        }

        [HttpPost]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public async Task<ActionResult<PromotionResponse>> Create([FromBody] PromotionRequest request)
        {
            return Ok(await _promotionService.CreateAsync(request));
        }

        [HttpPut("{id:long}")]
        [Authorize(Policy = AuthorizationPolicies.AdminOnly)]
        public async Task<ActionResult<PromotionResponse>> Update(long id, [FromBody] PromotionRequest request)
        {
            return Ok(await _promotionService.UpdateAsync(id, request));
        }
    }
}
