using AuthService.DTOs.Request;
using AuthService.DTOs.Response;
using AuthService.Helpers;
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

        // POST /api/v1/auth/register  (gửi OTP xác thực về email, chưa trả token)
        [HttpPost("register")]
        public async Task<ActionResult<OtpSentResponse>> Register([FromBody] RegisterRequest request)
        {
            var result = await _authService.RegisterAsync(request);
            return Ok(result);
        }

        // POST /api/v1/auth/verify-email  (đúng OTP -> kích hoạt tài khoản, trả token như đăng nhập)
        [HttpPost("verify-email")]
        public async Task<ActionResult<AuthResponse>> VerifyEmail([FromBody] VerifyEmailRequest request)
        {
            var result = await _authService.VerifyEmailAsync(request);
            return Ok(result);
        }

        // POST /api/v1/auth/resend-verification
        [HttpPost("resend-verification")]
        public async Task<ActionResult<OtpSentResponse>> ResendVerification([FromBody] EmailRequest request)
        {
            var result = await _authService.ResendVerificationOtpAsync(request.Email);
            return Ok(result);
        }

        // POST /api/v1/auth/login
        [HttpPost("login")]
        public async Task<ActionResult<AuthResponse>> Login([FromBody] LoginRequest request)
        {
            var result = await _authService.LoginAsync(request);
            return Ok(result);
        }

        // POST /api/v1/auth/forgot-password
        [HttpPost("forgot-password")]
        public async Task<ActionResult<OtpSentResponse>> ForgotPassword([FromBody] EmailRequest request)
        {
            var result = await _authService.ForgotPasswordAsync(request.Email);
            return Ok(result);
        }

        // POST /api/v1/auth/reset-password
        [HttpPost("reset-password")]
        public async Task<ActionResult<MessageResponse>> ResetPassword([FromBody] ResetPasswordRequest request)
        {
            await _authService.ResetPasswordAsync(request);
            return Ok(new MessageResponse { Message = "Đặt lại mật khẩu thành công. Vui lòng đăng nhập lại." });
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
            var result = await _authService.GetCurrentUserAsync(User.GetUserId());
            return Ok(result);
        }

        // Quản lý user / role cho Admin: xem UsersController, RolesController
    }
}
