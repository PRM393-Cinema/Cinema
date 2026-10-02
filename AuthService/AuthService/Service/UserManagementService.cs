using AuthService.DTOs.Request;
using AuthService.DTOs.Response;
using AuthService.Exception;
using AuthService.Helpers;
using AuthService.Models;
using AuthService.Repository;

namespace AuthService.Service
{
    public class UserManagementService : IUserManagementService
    {
        private const string AdminRole = "ROLE_ADMIN";
        private const int MaxPageSize = 50;

        private readonly IUserRepository _userRepository;
        private readonly IRefreshTokenRepository _refreshTokenRepository;
        private readonly ILogger<UserManagementService> _logger;

        public UserManagementService(
            IUserRepository userRepository,
            IRefreshTokenRepository refreshTokenRepository,
            ILogger<UserManagementService> logger)
        {
            _userRepository = userRepository;
            _refreshTokenRepository = refreshTokenRepository;
            _logger = logger;
        }

        public async Task<PagedResult<UserResponse>> GetUsersAsync(
            long actorId, string? keyword, string? role, bool? enabled, int page, int size)
        {
            await EnsureActiveAdminAsync(actorId);

            page = Math.Max(page, 1);
            size = size <= 0 ? 10 : Math.Min(size, MaxPageSize);

            var (items, totalCount) = await _userRepository.SearchAsync(
                keyword,
                string.IsNullOrWhiteSpace(role) ? null : NormalizeRole(role),
                enabled,
                page,
                size);

            return new PagedResult<UserResponse>
            {
                Items = items.Select(u => u.ToResponse()).ToList(),
                PageNumber = page,
                PageSize = size,
                TotalCount = totalCount,
                TotalPages = (int)Math.Ceiling(totalCount / (double)size)
            };
        }

        public async Task<UserResponse> GetUserAsync(long actorId, long userId)
        {
            await EnsureActiveAdminAsync(actorId);

            return (await GetUserEntityAsync(userId)).ToResponse();
        }

        public async Task<List<string>> GetRolesAsync()
        {
            return (await _userRepository.GetAllRolesAsync()).Select(r => r.Name).ToList();
        }

        public async Task<UserResponse> CreateUserAsync(long actorId, CreateUserRequest request)
        {
            await EnsureActiveAdminAsync(actorId);

            var email = request.Email.Trim().ToLowerInvariant();

            if (await _userRepository.ExistsByEmailAsync(email))
            {
                throw new BusinessException($"Email '{email}' đã được đăng ký.");
            }

            var roles = await ResolveRolesAsync(request.Roles);

            var user = new User
            {
                Email = email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
                FullName = request.FullName.Trim(),
                Phone = string.IsNullOrWhiteSpace(request.Phone) ? null : request.Phone.Trim(),
                Enabled = true,
                // Admin tạo trực tiếp nên không cần xác thực email bằng OTP
                EmailVerified = true,
                CreatedAt = DateTime.Now,
                Roles = roles
            };

            await _userRepository.AddAsync(user);

            _logger.LogInformation(
                "Admin {ActorId} created user {UserId} with roles {Roles}",
                actorId, user.UserId, string.Join(",", roles.Select(r => r.Name)));

            return user.ToResponse();
        }

        // Role mới có trong token khi user đăng nhập lại hoặc refresh (token cũ còn hạn tối đa Jwt:AccessTokenMinutes)
        public async Task<UserResponse> UpdateRolesAsync(long actorId, long userId, UpdateUserRolesRequest request)
        {
            await EnsureActiveAdminAsync(actorId);

            var user = await GetUserEntityAsync(userId);
            var roles = await ResolveRolesAsync(request.Roles);

            if (userId == actorId && roles.All(r => r.Name != AdminRole))
            {
                throw new BusinessException("Không thể tự bỏ quyền admin của chính mình.");
            }

            user.Roles.Clear();
            foreach (var role in roles)
            {
                user.Roles.Add(role);
            }

            await _userRepository.SaveChangesAsync();

            _logger.LogInformation(
                "Admin {ActorId} set roles of user {UserId} to {Roles}",
                actorId, userId, string.Join(",", roles.Select(r => r.Name)));

            return user.ToResponse();
        }

        public async Task<UserResponse> UpdateStatusAsync(long actorId, long userId, bool enabled)
        {
            await EnsureActiveAdminAsync(actorId);

            if (userId == actorId && !enabled)
            {
                throw new BusinessException("Không thể tự khoá tài khoản của chính mình.");
            }

            var user = await GetUserEntityAsync(userId);

            if (user.Enabled != enabled)
            {
                user.Enabled = enabled;
                await _userRepository.SaveChangesAsync();

                if (!enabled)
                {
                    // Đăng xuất mọi thiết bị: không refresh được nữa.
                    // Access token đang có vẫn dùng được tới khi hết hạn (tối đa Jwt:AccessTokenMinutes).
                    await _refreshTokenRepository.DeleteAllByUserIdAsync(userId);
                }

                _logger.LogInformation(
                    "Admin {ActorId} {Action} user {UserId}",
                    actorId, enabled ? "unlocked" : "locked", userId);
            }

            return user.ToResponse();
        }

        // Token có thể được cấp trước khi admin bị khoá / bị bỏ quyền: kiểm tra lại trạng thái hiện tại trong DB
        private async Task EnsureActiveAdminAsync(long actorId)
        {
            var actor = await _userRepository.GetByIdAsync(actorId);

            if (actor is null || !actor.Enabled || actor.Roles.All(r => r.Name != AdminRole))
            {
                throw new ForbiddenException("Tài khoản của bạn không còn quyền quản trị.");
            }
        }

        private async Task<List<Role>> ResolveRolesAsync(IEnumerable<string> requested)
        {
            var names = requested
                .Where(r => !string.IsNullOrWhiteSpace(r))
                .Select(NormalizeRole)
                .Distinct()
                .ToList();

            if (names.Count == 0)
            {
                throw new BusinessException("Phải chọn ít nhất một vai trò.");
            }

            var roles = await _userRepository.GetRolesByNamesAsync(names);
            var missing = names.Except(roles.Select(r => r.Name)).ToList();

            if (missing.Count > 0)
            {
                throw new BusinessException($"Vai trò không hợp lệ: {string.Join(", ", missing)}.");
            }

            return roles;
        }

        // "staff" / "STAFF" / "ROLE_STAFF" -> "ROLE_STAFF"
        private static string NormalizeRole(string role)
        {
            var name = role.Trim().ToUpperInvariant();
            return name.StartsWith("ROLE_") ? name : "ROLE_" + name;
        }

        private async Task<User> GetUserEntityAsync(long userId)
        {
            return await _userRepository.GetByIdAsync(userId)
                ?? throw new NotFoundException($"Không tìm thấy người dùng với ID {userId}.");
        }
    }
}
