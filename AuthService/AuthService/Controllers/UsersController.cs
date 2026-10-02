using AuthService.DTOs.Request;
using AuthService.DTOs.Response;
using AuthService.Helpers;
using AuthService.Service;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AuthService.Controllers
{
    // Quản lý user cho Admin: tạo tài khoản nhân viên, đổi role, khoá / mở tài khoản
    [ApiController]
    [Route("api/v1/auth/users")]
    [Authorize(Roles = "ROLE_ADMIN")]
    public class UsersController : ControllerBase
    {
        private readonly IUserManagementService _userManagementService;

        public UsersController(IUserManagementService userManagementService)
        {
            _userManagementService = userManagementService;
        }

        // GET /api/v1/auth/users?keyword=&role=&enabled=&page=1&size=10
        [HttpGet]
        public async Task<ActionResult<PagedResult<UserResponse>>> GetUsers(
            [FromQuery] string? keyword,
            [FromQuery] string? role,
            [FromQuery] bool? enabled,
            [FromQuery] int page = 1,
            [FromQuery] int size = 10)
        {
            return Ok(await _userManagementService.GetUsersAsync(User.GetUserId(), keyword, role, enabled, page, size));
        }

        // GET /api/v1/auth/users/{id}
        [HttpGet("{id:long}")]
        public async Task<ActionResult<UserResponse>> GetUser(long id)
        {
            return Ok(await _userManagementService.GetUserAsync(User.GetUserId(), id));
        }

        // POST /api/v1/auth/users  (tài khoản dùng được ngay, không cần OTP)
        [HttpPost]
        public async Task<ActionResult<UserResponse>> CreateUser([FromBody] CreateUserRequest request)
        {
            var result = await _userManagementService.CreateUserAsync(User.GetUserId(), request);
            return CreatedAtAction(nameof(GetUser), new { id = result.UserId }, result);
        }

        // PUT /api/v1/auth/users/{id}/roles  (thay toàn bộ role)
        [HttpPut("{id:long}/roles")]
        public async Task<ActionResult<UserResponse>> UpdateRoles(long id, [FromBody] UpdateUserRolesRequest request)
        {
            return Ok(await _userManagementService.UpdateRolesAsync(User.GetUserId(), id, request));
        }

        // PATCH /api/v1/auth/users/{id}/status  { "enabled": false } = khoá, true = mở lại
        [HttpPatch("{id:long}/status")]
        public async Task<ActionResult<UserResponse>> UpdateStatus(long id, [FromBody] UpdateUserStatusRequest request)
        {
            return Ok(await _userManagementService.UpdateStatusAsync(User.GetUserId(), id, request.Enabled!.Value));
        }
    }
}
