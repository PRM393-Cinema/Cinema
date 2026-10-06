namespace AuthService.Exception
{
    // Dịch vụ bên ngoài (SMTP...) đang lỗi, người dùng thử lại sau -> 503
    public class ServiceUnavailableException : System.Exception
    {
        public ServiceUnavailableException(string message) : base(message)
        {
        }
    }
}
