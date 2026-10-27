using AuthService.DTOs.Response;
using AuthService.Service;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AuthService.Controllers
{
    // Quầy bán vé tìm tài khoản khách hàng theo số điện thoại để bán vé / tích điểm
    [ApiController]
    [Route("api/v1/auth/members")]
    [Authorize(Roles = "ROLE_STAFF,ROLE_ADMIN")]
    public class MembersController : ControllerBase
    {
        private readonly IUserManagementService _userManagementService;

        public MembersController(IUserManagementService userManagementService)
        {
            _userManagementService = userManagementService;
        }

        // GET /api/v1/auth/members?phone=0901 234 567  (so theo chữ số, bỏ qua dấu cách / chấm / gạch)
        [HttpGet]
        public async Task<ActionResult<List<MemberResponse>>> FindByPhone([FromQuery] string? phone)
        {
            return Ok(await _userManagementService.FindMembersByPhoneAsync(phone));
        }
    }
}
