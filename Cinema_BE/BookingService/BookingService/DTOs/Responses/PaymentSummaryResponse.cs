namespace BookingService.DTOs.Responses
{
    // Doanh thu trong một khoảng thời gian (dashboard Admin), theo thời điểm tạo thanh toán
    public class PaymentSummaryResponse
    {
        public DateTime Start { get; set; }

        public DateTime End { get; set; }

        // Thanh toán đã nhận tiền (SUCCESS, kể cả đang chờ hoàn tiền)
        public int PaidCount { get; set; }

        // Tiền rạp đang giữ: SUCCESS + REFUND_PENDING
        public decimal Revenue { get; set; }

        // Tiền đã hoàn lại cho khách (REFUNDED)
        public decimal RefundedAmount { get; set; }
    }
}
