namespace AuthService.Service
{
    public interface IOtpService
    {
        // Tạo mã mới (thay thế mã cũ cùng mục đích) và trả về mã gốc để gửi email. DB chỉ lưu hash.
        Task<string> GenerateAsync(long userId, string purpose);

        // Đúng mã thì xóa mã (chỉ dùng một lần); sai, hết hạn hoặc hết lượt thì ném BusinessException
        Task VerifyAsync(long userId, string purpose, string code);

        // Số giây còn phải chờ trước khi được gửi mã mới (0 = gửi được ngay)
        Task<int> GetResendWaitSecondsAsync(long userId, string purpose);

        Task DeleteAsync(long userId, string purpose);
    }
}
