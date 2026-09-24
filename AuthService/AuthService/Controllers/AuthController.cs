using System.Security.Claims;
using AuthService.DTOs.Request;
using AuthService.DTOs.Response;
using AuthService.Exception;
using AuthService.Service;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AuthService.Controllers
{
    [ApiController]
    [Route("api/v1/auth")]
    public class AuthController : ControllerBase
    {
        private readonly IAuthService _authService;

        public AuthController(IAuthService authService)
        {
            _authService = authService;
        }

        // POST /api/v1/auth/register
        [HttpPost("register")]
        public async Task<ActionResult<AuthResponse>> Register([FromBody] RegisterRequest request)
        {
            var result = await _authService.RegisterAsync(request);
            return Ok(result);
        }

        // POST /api/v1/auth/login
        [HttpPost("login")]
        public async Task<ActionResult<AuthResponse>> Login([FromBody] LoginRequest request)
        {
            var result = await _authService.LoginAsync(request);
            return Ok(result);
        }

        // POST /api/v1/auth/refresh
        [HttpPost("refresh")]
        public async Task<ActionResult<AuthResponse>> Refresh([FromBody] RefreshTokenRequest request)
        {
            var result = await _authService.RefreshTokenAsync(request.RefreshToken);
            return Ok(result);
        }

        // POST /api/v1/auth/logout
        [Authorize]
        [HttpPost("logout")]
        public async Task<IActionResult> Logout([FromBody] RefreshTokenRequest request)
        {
            await _authService.LogoutAsync(request.RefreshToken);
            return NoContent(); // HTTP 204
        }

        // GET /api/v1/auth/me
        [Authorize]
        [HttpGet("me")]
        public async Task<ActionResult<UserResponse>> Me()
        {
            var userId = GetCurrentUserId();
            var result = await _authService.GetCurrentUserAsync(userId);
            return Ok(result);
        }

        // GET /api/v1/auth/users  (chỉ ADMIN)
        [Authorize(Roles = "ROLE_ADMIN")]
        [HttpGet("users")]
        public async Task<ActionResult<List<UserResponse>>> GetAllUsers()
        {
            var result = await _authService.GetAllUsersAsync();
            return Ok(result);
        }

        private long GetCurrentUserId()
        {
            var value = User.FindFirstValue(ClaimTypes.NameIdentifier)
                        ?? User.FindFirstValue("sub");

            if (!long.TryParse(value, out var userId))
            {
                throw new UnauthorizedException("Token không chứa thông tin người dùng hợp lệ.");
            }

            return userId;
        }
    }
}
