using AuthService.DTOs.Request;
using AuthService.DTOs.Response;

namespace AuthService.Service
{
    public interface IAuthService
    {
        Task<AuthResponse> RegisterAsync(RegisterRequest request);

        Task<AuthResponse> LoginAsync(LoginRequest request);

        Task<AuthResponse> RefreshTokenAsync(string refreshToken);

        Task LogoutAsync(string refreshToken);

        Task<UserResponse> GetCurrentUserAsync(long userId);

        Task<List<UserResponse>> GetAllUsersAsync();
    }
}
