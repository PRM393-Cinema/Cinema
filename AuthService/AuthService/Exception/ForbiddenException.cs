namespace AuthService.Exception
{
    // Đã xác định được người dùng nhưng không được phép thực hiện -> 403.
    // ErrorCode trả về trong ProblemDetails để client phân biệt từng trường hợp (vd: EMAIL_NOT_VERIFIED).
    public class ForbiddenException : System.Exception
    {
        public string? ErrorCode { get; }

        public ForbiddenException(string message, string? errorCode = null) : base(message)
        {
            ErrorCode = errorCode;
        }
    }
}
