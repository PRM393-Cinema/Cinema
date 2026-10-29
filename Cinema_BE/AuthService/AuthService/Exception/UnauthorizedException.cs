namespace AuthService.Exception
{
    // Dùng cho lỗi xác thực nghiệp vụ (sai thông tin đăng nhập, token không hợp lệ...) -> 401
    public class UnauthorizedException : System.Exception
    {
        // Trả trong ProblemDetails để client nhận biết trường hợp (vd: ACCOUNT_LOCKED)
        public string? ErrorCode { get; }

        public UnauthorizedException(string message, string? errorCode = null) : base(message)
        {
            ErrorCode = errorCode;
        }
    }
}
