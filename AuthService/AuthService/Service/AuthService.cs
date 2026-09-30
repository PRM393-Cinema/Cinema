using AuthService.Configuration;
using AuthService.DTOs.Request;
using AuthService.DTOs.Response;
using AuthService.Exception;
using AuthService.Helpers;
using AuthService.Models;
using AuthService.Repository;
using Microsoft.Extensions.Options;

namespace AuthService.Service
{
    public class AuthService : IAuthService
    {
        private readonly IUserRepository _userRepository;
        private readonly IRefreshTokenRepository _refreshTokenRepository;
        private readonly IJwtService _jwtService;
        private readonly JwtOptions _jwtOptions;
        private readonly ILogger<AuthService> _logger;

        // Người dùng tự đăng ký luôn là khách hàng
        private const string DefaultRole = "ROLE_CUSTOMER";

        public AuthService(
            IUserRepository userRepository,
            IRefreshTokenRepository refreshTokenRepository,
            IJwtService jwtService,
            IOptions<JwtOptions> jwtOptions,
            ILogger<AuthService> logger)
        {
            _userRepository = userRepository;
            _refreshTokenRepository = refreshTokenRepository;
            _jwtService = jwtService;
            _jwtOptions = jwtOptions.Value;
            _logger = logger;
        }

        // ======= REGISTER =======
        public async Task<AuthResponse> RegisterAsync(RegisterRequest request)
        {
            var email = request.Email.Trim().ToLowerInvariant();

            if (await _userRepository.ExistsByEmailAsync(email))
            {
                throw new BusinessException($"Email '{email}' đã được đăng ký.");
            }

            var role = await _userRepository.GetRoleByNameAsync(DefaultRole)
                ?? throw new BusinessException($"Vai trò mặc định '{DefaultRole}' không tồn tại trong hệ thống.");

            var user = new User
            {
                Email = email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
                FullName = request.FullName.Trim(),
                Phone = string.IsNullOrWhiteSpace(request.Phone) ? null : request.Phone.Trim(),
                Enabled = true,
                CreatedAt = DateTime.Now,
                Roles = new List<Role> { role }
            };

            await _userRepository.AddAsync(user);

            return await BuildAuthResponseAsync(user);
        }

        // ======= LOGIN =======
        public async Task<AuthResponse> LoginAsync(LoginRequest request)
        {
            var email = request.Email.Trim().ToLowerInvariant();

            var user = await _userRepository.GetByEmailAsync(email)
                ?? throw new UnauthorizedException("Email hoặc mật khẩu không đúng.");

            if (!user.Enabled)
            {
                throw new UnauthorizedException("Tài khoản đã bị vô hiệu hóa.");
            }

            if (!BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
            {
                throw new UnauthorizedException("Email hoặc mật khẩu không đúng.");
            }

            return await BuildAuthResponseAsync(user);
        }

        // ======= REFRESH TOKEN (có xoay vòng token) =======
        public async Task<AuthResponse> RefreshTokenAsync(string refreshToken)
        {
            var stored = await _refreshTokenRepository.GetByTokenAsync(refreshToken)
                ?? throw new UnauthorizedException("Refresh token không hợp lệ.");

            if (stored.Revoked)
            {
                throw new UnauthorizedException("Refresh token đã bị thu hồi.");
            }

            if (stored.ExpiresAt < DateTime.Now)
            {
                throw new UnauthorizedException("Refresh token đã hết hạn.");
            }

            if (stored.User is null)
            {
                throw new UnauthorizedException("Không tìm thấy người dùng gắn với refresh token.");
            }

            // Thu hồi token cũ và cấp cặp token mới (rotation)
            stored.Revoked = true;

            return await BuildAuthResponseAsync(stored.User);
        }

        // ======= LOGOUT (thu hồi refresh token) =======
        public async Task LogoutAsync(string refreshToken)
        {
            var stored = await _refreshTokenRepository.GetByTokenAsync(refreshToken);

            if (stored is not null && !stored.Revoked)
            {
                stored.Revoked = true;
                await _refreshTokenRepository.SaveChangesAsync();

                await CleanUpStaleTokensAsync(stored.UserId);
            }
        }

        // ======= GET CURRENT USER =======
        public async Task<UserResponse> GetCurrentUserAsync(long userId)
        {
            var user = await _userRepository.GetByIdAsync(userId)
                ?? throw new NotFoundException($"Không tìm thấy người dùng với ID {userId}.");

            return user.ToResponse();
        }

        // ======= GET ALL USERS (ADMIN) =======
        public async Task<List<UserResponse>> GetAllUsersAsync()
        {
            var users = await _userRepository.GetAllAsync();
            return users.Select(u => u.ToResponse()).ToList();
        }

        // ======= HELPER: tạo access token + refresh token và lưu lại =======
        private async Task<AuthResponse> BuildAuthResponseAsync(User user)
        {
            var (accessToken, expiresAt) = _jwtService.GenerateAccessToken(user);
            var refreshToken = _jwtService.GenerateRefreshToken();

            await _refreshTokenRepository.AddAsync(new RefreshToken
            {
                UserId = user.UserId,
                Token = refreshToken,
                ExpiresAt = DateTime.Now.AddDays(_jwtOptions.RefreshTokenDays),
                Revoked = false
            });

            // Lưu một lần: gồm cả việc thu hồi token cũ (nếu có) và token mới
            await _refreshTokenRepository.SaveChangesAsync();

            // Token cũ vừa bị thu hồi (khi refresh) cũng được dọn luôn ở bước này
            await CleanUpStaleTokensAsync(user.UserId);

            return new AuthResponse
            {
                AccessToken = accessToken,
                RefreshToken = refreshToken,
                TokenType = "Bearer",
                ExpiresAt = expiresAt,
                User = user.ToResponse()
            };
        }

        // ======= HELPER: dọn refresh token đã hết hạn / đã thu hồi =======
        // Giữ bảng refresh_tokens không phình mãi. Token còn hạn được giữ lại (đăng nhập nhiều thiết bị).
        // Chỉ là dọn dẹp: lỗi ở đây không được làm hỏng đăng nhập/đăng xuất.
        private async Task CleanUpStaleTokensAsync(long userId)
        {
            try
            {
                await _refreshTokenRepository.DeleteExpiredOrRevokedAsync(userId, DateTime.Now);
            }
            catch (System.Exception ex)
            {
                _logger.LogWarning(ex, "Could not clean up stale refresh tokens for user {UserId}", userId);
            }
        }
    }
}
