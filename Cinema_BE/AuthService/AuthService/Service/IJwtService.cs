using AuthService.Models;

namespace AuthService.Service
{
    public interface IJwtService
    {
        (string Token, DateTime ExpiresAt) GenerateAccessToken(User user);

        string GenerateRefreshToken();
    }
}
