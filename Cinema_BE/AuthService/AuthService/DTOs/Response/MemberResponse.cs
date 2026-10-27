namespace AuthService.DTOs.Response
{
    // Khách hàng thành viên tìm theo số điện thoại (quầy bán vé)
    public class MemberResponse
    {
        public long UserId { get; set; }

        public string Email { get; set; } = null!;

        public string? FullName { get; set; }

        public string? Phone { get; set; }
    }
}
