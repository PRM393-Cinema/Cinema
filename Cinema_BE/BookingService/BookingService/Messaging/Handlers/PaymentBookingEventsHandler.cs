using BookingService.Services.Interfaces;

namespace BookingService.Messaging.Handlers
{
    // Phía Payment phản ứng với thay đổi của booking (luồng 8.2):
    // - booking.expired: payment chưa trả -> FAILED
    // - booking.cancelled: payment chưa trả -> FAILED (huỷ luôn link PayOS); đã trả -> tạo yêu cầu hoàn tiền
    // Idempotent: payment không còn PENDING thì bỏ qua, mỗi payment chỉ có một yêu cầu hoàn tiền.
    public sealed class PaymentBookingEventsHandler : IIntegrationEventHandler
    {
        private readonly IPaymentService _paymentService;
        private readonly IRefundService _refundService;

        public PaymentBookingEventsHandler(
            IPaymentService paymentService,
            IRefundService refundService)
        {
            _paymentService = paymentService;
            _refundService = refundService;
        }

        public async Task HandleAsync(IntegrationEvent integrationEvent, CancellationToken cancellationToken)
        {
            var data = integrationEvent.GetData<BookingEventData>();

            switch (integrationEvent.EventType)
            {
                case EventTypes.BookingExpired:
                    await _paymentService.FailUnpaidPaymentsOfBookingAsync(
                        data.BookingId,
                        "Booking expired before payment.",
                        cancelPayOsLink: false);
                    break;

                case EventTypes.BookingCancelled:
                    await _paymentService.FailUnpaidPaymentsOfBookingAsync(
                        data.BookingId,
                        "Booking was cancelled.",
                        cancelPayOsLink: true);

                    await _refundService.RequestRefundForBookingAsync(
                        data.BookingId,
                        string.IsNullOrWhiteSpace(data.Reason)
                            ? $"Booking {data.BookingCode} was cancelled."
                            : data.Reason);
                    break;
            }
        }
    }
}
