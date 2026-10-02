namespace MovieService.Exception
{
    // Trạng thái dữ liệu không cho phép thao tác (trùng lịch phòng, suất chiếu đã huỷ...) -> 409 (SRS §12)
    public class ConflictException : System.Exception
    {
        public ConflictException(string message) : base(message)
        {
        }
    }
}
