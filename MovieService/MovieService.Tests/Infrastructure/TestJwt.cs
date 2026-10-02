using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace MovieService.Tests.Infrastructure;

// Tạo JWT giống AuthService (cùng issuer / audience / kiểu claim) để gọi API trong test
public static class TestJwt
{
    public const string SecretKey = "test-only-jwt-secret-key-with-at-least-32-chars";
    public const string Issuer = "CinemaAuthService";
    public const string Audience = "CinemaClients";

    public static string Create(
        long userId,
        string email,
        string role,
        TimeSpan? lifetime = null,
        string? secretKey = null)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, userId.ToString()),
            new(JwtRegisteredClaimNames.Email, email),
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new(ClaimTypes.Role, role)
        };

        var now = DateTime.UtcNow;
        var expires = now.Add(lifetime ?? TimeSpan.FromMinutes(30));

        var token = new JwtSecurityToken(
            Issuer,
            Audience,
            claims,
            notBefore: expires < now ? expires.AddMinutes(-5) : now,
            expires: expires,
            signingCredentials: new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey ?? SecretKey)),
                SecurityAlgorithms.HmacSha256));

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
