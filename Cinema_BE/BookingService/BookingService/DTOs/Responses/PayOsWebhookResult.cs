namespace BookingService.DTOs.Responses
{
    // Kết quả xử lý webhook PayOS. Chữ ký sai -> 400; còn lại luôn trả 200 để PayOS không gửi lại
    public sealed class PayOsWebhookResult
    {
        public bool SignatureValid { get; init; }

        public string Message { get; init; } = string.Empty;
    }
}
