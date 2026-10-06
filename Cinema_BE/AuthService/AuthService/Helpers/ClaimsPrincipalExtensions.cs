using System.Security.Claims;
using AuthService.Exception;

namespace AuthService.Helpers
{
    public static class ClaimsPrincipalExtensions
    {
        // Id người dùng trong token (claim NameIdentifier hoặc sub)
        public static long GetUserId(this ClaimsPrincipal user)
        {
            var value = user.FindFirstValue(ClaimTypes.NameIdentifier) ?? user.FindFirstValue("sub");

            if (!long.TryParse(value, out var userId))
            {
                throw new UnauthorizedException("Token không chứa thông tin người dùng hợp lệ.");
            }

            return userId;
        }
    }
}
