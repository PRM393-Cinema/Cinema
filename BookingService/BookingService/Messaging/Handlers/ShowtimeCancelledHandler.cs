using BookingService.Services.Interfaces;

namespace BookingService.Messaging.Handlers
{
    // MovieService huỷ suất chiếu -> huỷ mọi booking còn hiệu lực của suất đó.
    // Mỗi booking bị huỷ phát booking.cancelled: khách nhận email, booking đã trả tiền được tạo yêu cầu hoàn.
    public sealed class ShowtimeCancelledHandler : IIntegrationEventHandler
    {
        private readonly IBookingService _bookingService;
        private readonly ILogger<ShowtimeCancelledHandler> _logger;

        public ShowtimeCancelledHandler(
            IBookingService bookingService,
            ILogger<ShowtimeCancelledHandler> logger)
        {
            _bookingService = bookingService;
            _logger = logger;
        }

        public async Task HandleAsync(IntegrationEvent integrationEvent, CancellationToken cancellationToken)
        {
            var data = integrationEvent.GetData<ShowtimeCancelledEventData>();

            var cancelled = await _bookingService.CancelBookingsOfShowtimeAsync(
                data.ShowtimeId,
                "Suất chiếu bị huỷ");

            _logger.LogInformation(
                "Showtime {ShowtimeId} was cancelled, {Count} booking(s) cancelled.",
                data.ShowtimeId,
                cancelled);
        }
    }
}
