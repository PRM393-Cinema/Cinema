using System.Security.Cryptography;
using AuthService.Configuration;
using AuthService.Exception;
using AuthService.Models;
using AuthService.Repository;
using Microsoft.Extensions.Options;

namespace AuthService.Service
{
    public class OtpService : IOtpService
    {
        private readonly IOtpCodeRepository _otpCodeRepository;
        private readonly OtpOptions _options;

        public OtpService(IOtpCodeRepository otpCodeRepository, IOptions<OtpOptions> options)
        {
            _otpCodeRepository = otpCodeRepository;
            _options = options.Value;
        }

        public async Task<string> GenerateAsync(long userId, string purpose)
        {
            // Mỗi user chỉ giữ một mã cho mỗi mục đích: mã mới thay thế mã cũ
            await _otpCodeRepository.DeleteAsync(userId, purpose);

            var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
            var now = DateTime.Now;

            await _otpCodeRepository.AddAsync(new OtpCode
            {
                UserId = userId,
                Purpose = purpose,
                // Hash bằng BCrypt như mật khẩu: lộ DB cũng không dò ra mã kịp trước khi mã hết hạn
                CodeHash = BCrypt.Net.BCrypt.HashPassword(code),
                ExpiresAt = now.AddMinutes(_options.ExpiryMinutes),
                Attempts = 0,
                CreatedAt = now
            });

            await _otpCodeRepository.SaveChangesAsync();

            return code;
        }

        public async Task VerifyAsync(long userId, string purpose, string code)
        {
            var otp = await _otpCodeRepository.GetLatestAsync(userId, purpose);

            if (otp is null || otp.ExpiresAt < DateTime.Now)
            {
                throw new BusinessException("Mã OTP không đúng hoặc đã hết hạn. Vui lòng yêu cầu mã mới.");
            }

            // Trừ lượt trước rồi mới so mã, để không thể đoán mã bằng nhiều request song song
            if (!await _otpCodeRepository.TryUseAttemptAsync(otp.Id, _options.MaxAttempts))
            {
                throw new BusinessException("Bạn đã nhập sai quá số lần cho phép. Vui lòng yêu cầu mã mới.");
            }

            if (!BCrypt.Net.BCrypt.Verify(code, otp.CodeHash))
            {
                var remaining = _options.MaxAttempts - (otp.Attempts + 1);

                throw new BusinessException(remaining > 0
                    ? $"Mã OTP không đúng. Bạn còn {remaining} lần thử."
                    : "Mã OTP không đúng. Bạn đã hết lượt thử, vui lòng yêu cầu mã mới.");
            }

            // Mã chỉ dùng được một lần
            await _otpCodeRepository.DeleteAsync(userId, purpose);
        }

        public async Task<int> GetResendWaitSecondsAsync(long userId, string purpose)
        {
            var latest = await _otpCodeRepository.GetLatestAsync(userId, purpose);

            if (latest is null)
            {
                return 0;
            }

            var wait = _options.ResendCooldownSeconds - (DateTime.Now - latest.CreatedAt).TotalSeconds;

            return wait > 0 ? (int)Math.Ceiling(wait) : 0;
        }

        public async Task DeleteAsync(long userId, string purpose)
        {
            await _otpCodeRepository.DeleteAsync(userId, purpose);
        }
    }
}
