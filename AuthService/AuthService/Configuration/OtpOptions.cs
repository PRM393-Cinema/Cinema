namespace AuthService.Configuration
{
    public class OtpOptions
    {
        // Thời gian mã OTP còn hiệu lực
        public int ExpiryMinutes { get; set; } = 5;

        // Số lần được nhập một mã, hết lượt thì phải yêu cầu mã mới
        public int MaxAttempts { get; set; } = 5;

        // Thời gian chờ tối thiểu giữa hai lần gửi mã cho cùng một tài khoản
        public int ResendCooldownSeconds { get; set; } = 60;
    }
}
