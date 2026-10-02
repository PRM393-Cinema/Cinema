using AuthService.DTOs.Request;
using AuthService.DTOs.Response;

namespace AuthService.Service
{
    // Quản lý user / role dành cho Admin. actorId = id của admin đang thao tác (lấy từ token)
    public interface IUserManagementService
    {
        Task<PagedResult<UserResponse>> GetUsersAsync(long actorId, string? keyword, string? role, bool? enabled, int page, int size);

        Task<UserResponse> GetUserAsync(long actorId, long userId);

        Task<List<string>> GetRolesAsync();

        Task<UserResponse> CreateUserAsync(long actorId, CreateUserRequest request);

        Task<UserResponse> UpdateRolesAsync(long actorId, long userId, UpdateUserRolesRequest request);

        Task<UserResponse> UpdateStatusAsync(long actorId, long userId, bool enabled);
    }
}
