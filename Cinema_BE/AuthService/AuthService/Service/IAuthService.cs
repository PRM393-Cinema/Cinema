using AuthService.DTOs.Request;
using AuthService.DTOs.Response;

namespace AuthService.Service
{
    public interface IAuthService
    {
        Task<OtpSentResponse> RegisterAsync(RegisterRequest request);

        Task<AuthResponse> VerifyEmailAsync(VerifyEmailRequest request);

        Task<OtpSentResponse> ResendVerificationOtpAsync(string email);

        Task<AuthResponse> LoginAsync(LoginRequest request);

        Task<OtpSentResponse> ForgotPasswordAsync(string email);

        Task ResetPasswordAsync(ResetPasswordRequest request);

        Task<AuthResponse> RefreshTokenAsync(string refreshToken);

        Task LogoutAsync(string refreshToken);

        Task<UserResponse> GetCurrentUserAsync(long userId);

        Task<UserResponse> UpdateProfileAsync(long userId, UpdateProfileRequest request);

        // Đổi mật khẩu: đăng xuất mọi thiết bị khác, trả token mới cho thiết bị đang dùng
        Task<AuthResponse> ChangePasswordAsync(long userId, ChangePasswordRequest request);
    }
}
