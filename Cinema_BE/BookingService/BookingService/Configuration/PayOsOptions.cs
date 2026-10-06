namespace BookingService.Configuration
{
    public class PayOsOptions
    {
        public string BaseUrl { get; set; } = "https://api-merchant.payos.vn/";

        public string ClientId { get; set; } = string.Empty;

        public string ApiKey { get; set; } = string.Empty;

        public string ChecksumKey { get; set; } = string.Empty;
    }
}