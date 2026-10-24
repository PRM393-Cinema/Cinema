using System.ComponentModel.DataAnnotations;
using System.Text;
using System.Text.RegularExpressions;

namespace AuthService.Helpers
{
    // Quy tắc chung cho email, mật khẩu, họ tên, số điện thoại của tài khoản (đăng ký, đăng nhập, quên mật khẩu,
    // Admin tạo tài khoản). App Flutter kiểm tra giống hệt (lib/core/utils/account_validators.dart).
    public static class AccountRules
    {
        public const int EmailMaxLength = 150; // cột users.email

        public const int PasswordMinLength = 6;

        // BCrypt chỉ băm 72 byte đầu: dài hơn thì phần dư bị bỏ qua mà không báo
        public const int PasswordMaxBytes = 72;

        public const int FullNameMaxLength = 150; // cột users.full_name

        public const int PhoneMinDigits = 8;

        public const int PhoneMaxDigits = 15;

        public const int PhoneMaxLength = 20; // cột users.phone

        // Có tên miền với đuôi ít nhất 2 chữ cái, không dấu cách: chặn "a b@c", "abc@def"
        public static readonly Regex EmailPattern = new(
            @"^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$",
            RegexOptions.Compiled);

        // Chữ số, có thể bắt đầu bằng +, ngăn cách bằng dấu cách . - ( )
        public static readonly Regex PhonePattern = new(@"^\+?[0-9 .()-]+$", RegexOptions.Compiled);
    }

    // Email đúng định dạng và vừa cột users.email. Bỏ trống thì để [Required] báo.
    public sealed class AccountEmailAttribute : ValidationAttribute
    {
        protected override ValidationResult? IsValid(object? value, ValidationContext validationContext)
        {
            if (value is not string text || string.IsNullOrWhiteSpace(text))
            {
                return ValidationResult.Success;
            }

            var email = text.Trim();

            if (email.Length > AccountRules.EmailMaxLength)
            {
                return new ValidationResult($"Email must be at most {AccountRules.EmailMaxLength} characters");
            }

            return AccountRules.EmailPattern.IsMatch(email)
                ? ValidationResult.Success
                : new ValidationResult("Email is not valid");
        }
    }

    // Mật khẩu mới: 6 đến 72 ký tự. Chữ có dấu chiếm 2–3 byte nên mật khẩu tiếng Việt dài có thể quá 72 byte.
    public sealed class AccountPasswordAttribute : ValidationAttribute
    {
        protected override ValidationResult? IsValid(object? value, ValidationContext validationContext)
        {
            if (value is not string password || password.Length == 0)
            {
                return ValidationResult.Success;
            }

            if (password.Length < AccountRules.PasswordMinLength)
            {
                return new ValidationResult(
                    $"Password must be at least {AccountRules.PasswordMinLength} characters");
            }

            if (password.Length > AccountRules.PasswordMaxBytes)
            {
                return new ValidationResult(
                    $"Password must be at most {AccountRules.PasswordMaxBytes} characters");
            }

            return Encoding.UTF8.GetByteCount(password) > AccountRules.PasswordMaxBytes
                ? new ValidationResult(
                    "Password is too long: accented letters count as 2 or 3 characters, " +
                    $"use at most {AccountRules.PasswordMaxBytes} in total")
                : ValidationResult.Success;
        }
    }

    // Số điện thoại (không bắt buộc): 8 đến 15 chữ số, tối đa 20 ký tự kể cả dấu ngăn cách
    public sealed class AccountPhoneAttribute : ValidationAttribute
    {
        protected override ValidationResult? IsValid(object? value, ValidationContext validationContext)
        {
            if (value is not string text || string.IsNullOrWhiteSpace(text))
            {
                return ValidationResult.Success;
            }

            var phone = text.Trim();
            var digits = phone.Count(char.IsAsciiDigit);

            if (phone.Length > AccountRules.PhoneMaxLength ||
                !AccountRules.PhonePattern.IsMatch(phone) ||
                digits < AccountRules.PhoneMinDigits ||
                digits > AccountRules.PhoneMaxDigits)
            {
                return new ValidationResult(
                    $"Phone number must have {AccountRules.PhoneMinDigits} to {AccountRules.PhoneMaxDigits} digits");
            }

            return ValidationResult.Success;
        }
    }
}
