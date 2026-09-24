namespace AuthService.Exception
{
    // Dùng cho lỗi xác thực nghiệp vụ (sai thông tin đăng nhập, token không hợp lệ...) -> 401
    public class UnauthorizedException : System.Exception
    {
        public UnauthorizedException(string message) : base(message)
        {
        }
    }
}
