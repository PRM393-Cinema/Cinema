namespace AuthService.DTOs.Response
{
    public class OtpSentResponse
    {
        public string Email { get; set; } = null!;
        public string Message { get; set; } = null!;

        // Mã OTP hết hạn sau bao nhiêu giây
        public int ExpiresInSeconds { get; set; }

        // Sau bao nhiêu giây mới được yêu cầu gửi lại mã (dùng cho nút đếm ngược "Gửi lại mã")
        public int ResendAfterSeconds { get; set; }
    }
}
