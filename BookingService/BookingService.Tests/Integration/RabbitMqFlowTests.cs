using System.Net;
using BookingService.Data;
using BookingService.Models;
using BookingService.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using static BookingService.Tests.Infrastructure.BookingApi;

namespace BookingService.Tests.Integration;

// Event đi qua RabbitMQ thật (container): outbox -> exchange -> queue -> consumer (SRS tiêu chí 9, 10)
[Collection(RabbitMqCollection.Name)]
public class RabbitMqFlowTests
{
    private readonly RabbitMqApiFactory _factory;
    private readonly HttpClient _customer;

    public RabbitMqFlowTests(RabbitMqApiFactory factory)
    {
        _factory = factory;
        _customer = factory.ClientFor(TestUsers.CustomerAToken);
    }

    [Fact]
    public async Task PaidBooking_TicketEmailArrivesThroughRabbitMq()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(3));
        var id = await CreatePaidBookingAsync(_factory, _customer, showtime.Id, NewSeat());
        var code = await BookingCodeAsync(id);

        await Eventually.TrueAsync(
            () => Task.FromResult(_factory.Emails.To(TestUsers.CustomerA.Email)
                .Any(email => email.Subject.Contains(code) && email.Subject.StartsWith("Xác nhận"))),
            "the ticket email is sent by the notification consumer");

        Assert.Equal(0, await _factory.QueryAsync<BookingDbContext, int>(db =>
            db.Set<OutboxMessage>().CountAsync(message => message.PublishedAt == null)));
    }

    [Fact]
    public async Task CancellingPaidBooking_RefundIsRequestedAsynchronously()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(3));
        var id = await CreatePaidBookingAsync(_factory, _customer, showtime.Id, NewSeat());
        var code = await BookingCodeAsync(id);

        Assert.Equal(HttpStatusCode.OK,
            (await _customer.PostAsync($"/api/v1/bookings/{id}/cancel", null)).StatusCode);

        await Eventually.TrueAsync(
            async () => await _factory.QueryAsync<PaymentDbContext, bool>(db =>
                db.Refunds.AnyAsync(r => r.BookingId == id && r.Status == "PENDING")),
            "the payment consumer creates the refund request");

        await Eventually.TrueAsync(
            () => Task.FromResult(_factory.Emails.To(TestUsers.CustomerA.Email)
                .Any(email => email.Subject == $"Yêu cầu hoàn tiền đơn {code}")),
            "the refund email is sent");
    }

    private Task<string> BookingCodeAsync(long id)
    {
        return _factory.QueryAsync<BookingDbContext, string>(db =>
            db.Bookings.Where(b => b.Id == id).Select(b => b.BookingCode).SingleAsync());
    }
}
