namespace AuthService.Exception
{
    // Yêu cầu quá dày (vd: gửi lại OTP trong thời gian chờ) -> 429 kèm header Retry-After
    public class TooManyRequestsException : System.Exception
    {
        public int RetryAfterSeconds { get; }

        public TooManyRequestsException(string message, int retryAfterSeconds) : base(message)
        {
            RetryAfterSeconds = retryAfterSeconds;
        }
    }
}
