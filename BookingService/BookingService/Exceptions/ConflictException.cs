namespace BookingService.Exceptions
{
    // Ghế đã có người đặt hoặc trạng thái booking/payment không cho phép thao tác -> 409 (SRS §12)
    public sealed class ConflictException : Exception
    {
        public ConflictException(string message) : base(message)
        {
        }
    }
}
