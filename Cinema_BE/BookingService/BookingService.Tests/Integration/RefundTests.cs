using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Data;
using BookingService.Messaging;
using BookingService.Messaging.Handlers;
using BookingService.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using static BookingService.Tests.Infrastructure.BookingApi;

namespace BookingService.Tests.Integration;

// Huỷ vé + hoàn tiền (SRS §8.2) và các consumer xử lý event (gọi thẳng handler, không cần RabbitMQ)
[Collection(BookingApiCollection.Name)]
public class RefundTests
{
    private readonly BookingApiFactory _factory;
    private readonly HttpClient _customer;
    private readonly HttpClient _staff;

    public RefundTests(BookingApiFactory factory)
    {
        _factory = factory;
        _customer = factory.ClientFor(TestUsers.CustomerAToken);
        _staff = factory.ClientFor(TestUsers.StaffToken);
    }

    [Fact]
    public async Task CustomerCancelsPaidBookingEarly_ConsumerRequestsRefundOnce()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(3));
        var id = await CreatePaidBookingAsync(_factory, _customer, showtime.Id, NewSeat());

        var cancel = await _customer.PostAsync($"/api/v1/bookings/{id}/cancel?reason=Ban%20viec", null);
        Assert.Equal(HttpStatusCode.OK, cancel.StatusCode);

        var cancelled = Assert.Single(
            await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingCancelled, id));

        // Consumer nhận event (RabbitMQ có thể giao lại message: chạy 2 lần)
        await _factory.HandleAsync<PaymentBookingEventsHandler>(cancelled);
        await _factory.HandleAsync<PaymentBookingEventsHandler>(cancelled);

        var refunds = await _factory.QueryAsync<PaymentDbContext, List<Models.Refund>>(db =>
            db.Refunds.Where(r => r.BookingId == id).ToListAsync());

        var refund = Assert.Single(refunds);
        Assert.Equal("PENDING", refund.Status);
        Assert.Equal("Ban viec", refund.Reason);
        Assert.Equal("REFUND_PENDING", await PaymentStatusAsync(id));
        Assert.Single(await _factory.OutboxEventsAsync<PaymentDbContext>(EventTypes.PaymentRefundRequested, id));
    }

    [Fact]
    public async Task CustomerCannotCancelPaidBookingWithinTwoHours_StaffCan()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddMinutes(90));
        var id = await CreatePaidBookingAsync(_factory, _customer, showtime.Id, NewSeat());

        Assert.Equal(HttpStatusCode.Conflict,
            (await _customer.PostAsync($"/api/v1/bookings/{id}/cancel", null)).StatusCode);
        Assert.Equal(HttpStatusCode.OK,
            (await _staff.PostAsync($"/api/v1/bookings/{id}/cancel", null)).StatusCode);
    }

    [Fact]
    public async Task StaffRefund_ThenCompleteTransfer_MarksPaymentRefunded()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(3));
        var id = await CreatePaidBookingAsync(_factory, _customer, showtime.Id, NewSeat());
        var paymentId = await _factory.QueryAsync<PaymentDbContext, long>(db =>
            db.Payments.Where(p => p.BookingId == id).Select(p => p.Id).SingleAsync());

        var refundResponse = await _staff.PostAsync($"/api/v1/payments/{paymentId}/refund?reason=Rap%20bao%20tri", null);
        Assert.Equal(HttpStatusCode.OK, refundResponse.StatusCode);
        var refund = await refundResponse.Content.ReadFromJsonAsync<JsonElement>();
        var refundId = refund.GetProperty("id").GetInt64();

        Assert.Equal("CANCELLED", (await _customer.GetFromJsonAsync<JsonElement>($"/api/v1/bookings/{id}"))
            .GetProperty("status").GetString());
        Assert.Equal("0011223344", refund.GetProperty("payerAccountNumber").GetString());

        Assert.Equal(HttpStatusCode.BadRequest,
            (await _staff.PostAsJsonAsync($"/api/v1/payments/refunds/{refundId}/complete", new { note = "x" })).StatusCode);

        var complete = await _staff.PostAsJsonAsync(
            $"/api/v1/payments/refunds/{refundId}/complete",
            new { transactionRef = "FT26100212345", note = "Vietcombank" });
        Assert.Equal(HttpStatusCode.OK, complete.StatusCode);

        var completed = await complete.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("COMPLETED", completed.GetProperty("status").GetString());
        Assert.Equal(TestUsers.Staff.Id, completed.GetProperty("processedBy").GetInt64());
        Assert.Equal("REFUNDED", await PaymentStatusAsync(id));

        Assert.Equal(HttpStatusCode.Conflict,
            (await _staff.PostAsJsonAsync($"/api/v1/payments/refunds/{refundId}/complete",
                new { transactionRef = "FT-again" })).StatusCode);

        // Khách xem được yêu cầu hoàn tiền của mình, khách khác thì không
        Assert.Equal(HttpStatusCode.OK, (await _customer.GetAsync($"/api/v1/payments/{paymentId}/refund")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _factory.ClientFor(TestUsers.CustomerBToken)
            .GetAsync($"/api/v1/payments/{paymentId}/refund")).StatusCode);
    }

    [Fact]
    public async Task NotificationHandler_SendsTicketOnce_EvenIfMessageIsRedelivered()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(3));
        var id = await CreatePaidBookingAsync(_factory, _customer, showtime.Id, NewSeat());
        var confirmed = Assert.Single(
            await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingConfirmed, id));
        var bookingCode = confirmed.Data.GetProperty("bookingCode").GetString()!;

        await _factory.HandleAsync<NotificationEventHandler>(confirmed);
        await _factory.HandleAsync<NotificationEventHandler>(confirmed);

        var tickets = _factory.Emails.To(TestUsers.CustomerA.Email)
            .Where(email => email.Subject.Contains(bookingCode))
            .ToList();

        Assert.Single(tickets);
        Assert.Equal(1, await _factory.QueryAsync<NotificationDbContext, int>(db =>
            db.Notifications.CountAsync(n => n.EventId == confirmed.EventId && n.Status == "SENT")));
    }

    [Fact]
    public async Task ShowtimeCancelled_CancelsItsBookings_AndPaidOnesGetRefunded()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(4));
        var pending = (await CreateBookingAsync(_customer, showtime.Id, NewSeat())).GetProperty("id").GetInt64();
        var paid = await CreatePaidBookingAsync(_factory, _factory.ClientFor(TestUsers.CustomerBToken), showtime.Id, NewSeat());

        var showtimeCancelled = new IntegrationEvent
        {
            EventId = Guid.NewGuid().ToString(),
            EventType = EventTypes.ShowtimeCancelled,
            OccurredAt = DateTime.Now,
            Data = JsonSerializer.SerializeToElement(new ShowtimeCancelledEventData
            {
                ShowtimeId = showtime.Id,
                MovieId = showtime.MovieId,
                StartTime = showtime.StartTime,
                EndTime = showtime.EndTime
            }, MessagingJson.Options)
        };

        await _factory.HandleAsync<ShowtimeCancelledHandler>(showtimeCancelled);

        foreach (var id in new[] { pending, paid })
        {
            Assert.Equal("CANCELLED", (await _staff.GetFromJsonAsync<JsonElement>($"/api/v1/bookings/{id}"))
                .GetProperty("status").GetString());
        }

        var paidCancelled = Assert.Single(
            await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingCancelled, paid));
        Assert.Equal("SYSTEM", paidCancelled.Data.GetProperty("cancelledBy").GetString());

        await _factory.HandleAsync<PaymentBookingEventsHandler>(paidCancelled);
        Assert.Equal("REFUND_PENDING", await PaymentStatusAsync(paid));
    }

    private Task<string> PaymentStatusAsync(long bookingId)
    {
        return _factory.QueryAsync<PaymentDbContext, string>(db =>
            db.Payments.Where(p => p.BookingId == bookingId).Select(p => p.Status).SingleAsync());
    }
}
