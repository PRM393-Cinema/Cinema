namespace BookingService.Exceptions
{
    // Service phụ thuộc (MovieService, PayOS) tạm thời không dùng được: lỗi kết nối, quá thời gian chờ
    // hoặc circuit breaker đang mở -> 503 (SRS §12)
    public sealed class ServiceUnavailableException : Exception
    {
        public ServiceUnavailableException(string message, Exception? innerException = null)
            : base(message, innerException)
        {
        }
    }
}
