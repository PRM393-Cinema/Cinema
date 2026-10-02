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
    }
}
