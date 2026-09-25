namespace BookingService.DTOs.Responses
{
    public class PayOsCheckoutResponse
    {
        public long paymentId {  get; set; }
        public long orderCode {  get; set; }
        public string? checkoutUrl { get; set; }
    }
}
