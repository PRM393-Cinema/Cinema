using System.Security.Claims;

namespace BookingService.Helpers
{
    public static class ClaimsPrincipalExtensions
    {
        public static bool IsStaffOrAdmin(this ClaimsPrincipal user)
        {
            return user.IsInRole("ADMIN") ||
                   user.IsInRole("ROLE_ADMIN") ||
                   user.IsInRole("STAFF") ||
                   user.IsInRole("ROLE_STAFF");
        }

        public static long GetCurrentUserId(this ClaimsPrincipal user)
        {
            var value = user.FindFirstValue(ClaimTypes.NameIdentifier) ??
                        user.FindFirstValue("sub");

            if (!long.TryParse(value, out var userId))
            {
                throw new UnauthorizedAccessException(
                    "Token does not contain a valid user id.");
            }

            return userId;
        }

        public static string? GetEmail(this ClaimsPrincipal user)
        {
            return user.FindFirstValue(ClaimTypes.Email) ??
                   user.FindFirstValue("email");
        }
    }
}