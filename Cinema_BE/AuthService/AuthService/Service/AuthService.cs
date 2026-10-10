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
        private readonly IOtpService _otpService;
        private readonly IEmailSender _emailSender;
        private readonly JwtOptions _jwtOptions;
        private readonly OtpOptions _otpOptions;
        private readonly ILogger<AuthService> _logger;

        // Người dùng tự đăng ký luôn là khách hàng
        private const string DefaultRole = "ROLE_CUSTOMER";

        // Client dựa vào mã này (ProblemDetails.errorCode) để chuyển sang màn hình nhập OTP
        private const string EmailNotVerifiedCode = "EMAIL_NOT_VERIFIED";

        private const string InvalidOtpMessage = "Mã OTP không đúng hoặc đã hết hạn. Vui lòng yêu cầu mã mới.";

        public AuthService(
            IUserRepository userRepository,
            IRefreshTokenRepository refreshTokenRepository,
            IJwtService jwtService,
            IOtpService otpService,
            IEmailSender emailSender,
            IOptions<JwtOptions> jwtOptions,
            IOptions<OtpOptions> otpOptions,
            ILogger<AuthService> logger)
        {
            _userRepository = userRepository;
            _refreshTokenRepository = refreshTokenRepository;
            _jwtService = jwtService;
            _otpService = otpService;
            _emailSender = emailSender;
            _jwtOptions = jwtOptions.Value;
            _otpOptions = otpOptions.Value;
            _logger = logger;
        }

        // ======= REGISTER (tài khoản chỉ đăng nhập được sau khi xác thực email bằng OTP) =======
        public async Task<OtpSentResponse> RegisterAsync(RegisterRequest request)
        {
            var email = NormalizeEmail(request.Email);
            var user = await _userRepository.GetByEmailAsync(email);

            if (user is not null && user.EmailVerified)
            {
                throw new BusinessException($"Email '{email}' đã được đăng ký.");
            }

            if (user is null)
            {
                var role = await _userRepository.GetRoleByNameAsync(DefaultRole)
                    ?? throw new BusinessException($"Vai trò mặc định '{DefaultRole}' không tồn tại trong hệ thống.");

                user = new User
                {
                    Email = email,
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
                    FullName = request.FullName.Trim(),
                    Phone = string.IsNullOrWhiteSpace(request.Phone) ? null : request.Phone.Trim(),
                    Enabled = true,
                    EmailVerified = false,
                    CreatedAt = DateTime.Now,
                    Roles = new List<Role> { role }
                };

                await _userRepository.AddAsync(user);
            }
            else
            {
                // Email đã đăng ký nhưng chưa xác thực (vd: thoát app trước khi nhập OTP):
                // cho đăng ký lại, thông tin mới thay thông tin cũ và gửi mã mới
                await EnsureCanSendOtpAsync(user.UserId, OtpPurpose.VerifyEmail);

                user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);
                user.FullName = request.FullName.Trim();
                user.Phone = string.IsNullOrWhiteSpace(request.Phone) ? null : request.Phone.Trim();

                await _userRepository.SaveChangesAsync();
            }

            await SendOtpEmailAsync(user, OtpPurpose.VerifyEmail);

            return BuildOtpSentResponse(email, "Đăng ký thành công. Mã OTP xác thực đã được gửi tới email của bạn.");
        }

        // ======= VERIFY EMAIL (đúng OTP + đúng mật khẩu đã đăng ký -> kích hoạt và đăng nhập luôn) =======
        public async Task<AuthResponse> VerifyEmailAsync(VerifyEmailRequest request)
        {
            var email = NormalizeEmail(request.Email);

            var user = await _userRepository.GetByEmailAsync(email)
                ?? throw new BusinessException(InvalidOtpMessage);

            if (user.EmailVerified)
            {
                throw new BusinessException("Email đã được xác thực. Vui lòng đăng nhập.");
            }

            await _otpService.VerifyAsync(user.UserId, OtpPurpose.VerifyEmail, request.Otp);

            if (!BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
            {
                throw new BusinessException("Mật khẩu không khớp với lần đăng ký gần nhất. Vui lòng đăng ký lại.");
            }

            user.EmailVerified = true;
            await _userRepository.SaveChangesAsync();

            var response = await BuildAuthResponseAsync(user);

            await SendWelcomeEmailAsync(user);

            return response;
        }

        // ======= GỬI LẠI OTP XÁC THỰC EMAIL =======
        public async Task<OtpSentResponse> ResendVerificationOtpAsync(string email)
        {
            email = NormalizeEmail(email);

            var user = await _userRepository.GetByEmailAsync(email)
                ?? throw new NotFoundException($"Không tìm thấy tài khoản với email '{email}'.");

            if (user.EmailVerified)
            {
                throw new BusinessException("Email đã được xác thực. Vui lòng đăng nhập.");
            }

            await EnsureCanSendOtpAsync(user.UserId, OtpPurpose.VerifyEmail);
            await SendOtpEmailAsync(user, OtpPurpose.VerifyEmail);

            return BuildOtpSentResponse(email, "Mã OTP xác thực mới đã được gửi tới email của bạn.");
        }

        // ======= LOGIN =======
        public async Task<AuthResponse> LoginAsync(LoginRequest request)
        {
            var email = NormalizeEmail(request.Email);

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

            // Kiểm tra sau mật khẩu để người không biết mật khẩu không dò được trạng thái tài khoản
            if (!user.EmailVerified)
            {
                throw new ForbiddenException(
                    "Email chưa được xác thực. Vui lòng nhập mã OTP đã gửi tới email của bạn.",
                    EmailNotVerifiedCode);
            }

            return await BuildAuthResponseAsync(user);
        }

        // ======= QUÊN MẬT KHẨU: gửi OTP qua email =======
        public async Task<OtpSentResponse> ForgotPasswordAsync(string email)
        {
            email = NormalizeEmail(email);
            var user = await _userRepository.GetByEmailAsync(email);

            // Luôn trả cùng một phản hồi dù email có tồn tại hay không, để không dò được email nào đã đăng ký.
            // Còn trong thời gian chờ thì bỏ qua, không gửi thêm mã.
            if (user is not null && user.Enabled &&
                await _otpService.GetResendWaitSecondsAsync(user.UserId, OtpPurpose.ResetPassword) == 0)
            {
                await SendOtpEmailAsync(user, OtpPurpose.ResetPassword);
            }

            return BuildOtpSentResponse(email, "Nếu email đã được đăng ký, mã OTP đặt lại mật khẩu đã được gửi tới email đó.");
        }

        // ======= ĐẶT LẠI MẬT KHẨU BẰNG OTP =======
        public async Task ResetPasswordAsync(ResetPasswordRequest request)
        {
            var email = NormalizeEmail(request.Email);
            var user = await _userRepository.GetByEmailAsync(email);

            if (user is null || !user.Enabled)
            {
                throw new BusinessException(InvalidOtpMessage);
            }

            await _otpService.VerifyAsync(user.UserId, OtpPurpose.ResetPassword, request.Otp);

            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);

            if (!user.EmailVerified)
            {
                // Nhận được OTP qua email nghĩa là đã chứng minh sở hữu email
                user.EmailVerified = true;
                await _otpService.DeleteAsync(user.UserId, OtpPurpose.VerifyEmail);
            }

            await _userRepository.SaveChangesAsync();

            // Đăng xuất mọi thiết bị đang đăng nhập bằng mật khẩu cũ
            await _refreshTokenRepository.DeleteAllByUserIdAsync(user.UserId);
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

            // Tài khoản bị admin khoá thì không được cấp token mới
            if (!stored.User.Enabled)
            {
                throw new UnauthorizedException("Tài khoản đã bị vô hiệu hóa.");
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

            if (!user.Enabled)
            {
                throw new ForbiddenException(
                    "Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.", "ACCOUNT_LOCKED");
            }

            return user.ToResponse();
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

        // ======= HELPER: tạo OTP và gửi qua email =======
        private async Task SendOtpEmailAsync(User user, string purpose)
        {
            var otp = await _otpService.GenerateAsync(user.UserId, purpose);

            var email = purpose == OtpPurpose.VerifyEmail
                ? EmailTemplates.VerifyEmailOtp(user.Email, user.FullName, otp, _otpOptions.ExpiryMinutes)
                : EmailTemplates.ResetPasswordOtp(user.Email, user.FullName, otp, _otpOptions.ExpiryMinutes);

            try
            {
                await _emailSender.SendAsync(email);
            }
            catch (System.Exception ex)
            {
                _logger.LogError(ex, "Could not send {Purpose} OTP email to user {UserId}", purpose, user.UserId);

                // Bỏ mã vừa tạo để người dùng gửi lại được ngay, không phải chờ hết thời gian chờ
                await _otpService.DeleteAsync(user.UserId, purpose);

                throw new ServiceUnavailableException("Không gửi được email lúc này. Vui lòng thử lại sau ít phút.");
            }
        }

        // ======= HELPER: email chào mừng. Chỉ là thông báo: gửi lỗi không ảnh hưởng việc xác thực =======
        private async Task SendWelcomeEmailAsync(User user)
        {
            try
            {
                await _emailSender.SendAsync(EmailTemplates.Welcome(user.Email, user.FullName));
            }
            catch (System.Exception ex)
            {
                _logger.LogWarning(ex, "Could not send welcome email to user {UserId}", user.UserId);
            }
        }

        // ======= HELPER: chặn gửi OTP liên tục (bảo vệ hạn mức gửi của Gmail) =======
        private async Task EnsureCanSendOtpAsync(long userId, string purpose)
        {
            var waitSeconds = await _otpService.GetResendWaitSecondsAsync(userId, purpose);

            if (waitSeconds > 0)
            {
                throw new TooManyRequestsException(
                    $"Vui lòng đợi {waitSeconds} giây trước khi yêu cầu mã mới.", waitSeconds);
            }
        }

        private OtpSentResponse BuildOtpSentResponse(string email, string message)
        {
            return new OtpSentResponse
            {
                Email = email,
                Message = message,
                ExpiresInSeconds = _otpOptions.ExpiryMinutes * 60,
                ResendAfterSeconds = _otpOptions.ResendCooldownSeconds
            };
        }

        private static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();
    }
}
