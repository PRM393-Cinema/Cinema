using AuthService.DTOs.Response;
using AuthService.Models;

namespace AuthService.Helpers
{
    public static class MappingExtensions
    {
        public static UserResponse ToResponse(this User user)
        {
            return new UserResponse
            {
                UserId = user.UserId,
                Email = user.Email,
                FullName = user.FullName,
                Phone = user.Phone,
                Enabled = user.Enabled,
                EmailVerified = user.EmailVerified,
                CreatedAt = user.CreatedAt,
                Roles = user.Roles?.Select(r => r.Name).ToList() ?? new List<string>()
            };
        }
    }
}
