using BookingService.Services.Interfaces;

namespace BookingService.Messaging.Handlers;

public sealed class BookingRefundEventsHandler(IBookingService bookings) : IIntegrationEventHandler
{
    public Task HandleAsync(IntegrationEvent integrationEvent, CancellationToken cancellationToken)
    {
        var data = integrationEvent.GetData<PaymentEventData>();
        return bookings.ApplyRefundDecisionAsync(data.BookingId,
            integrationEvent.EventType == EventTypes.PaymentRefunded);
    }
}
