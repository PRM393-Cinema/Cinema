using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Tests.Infrastructure;
using BookingService.Data;
using BookingService.Models;
using Microsoft.Extensions.DependencyInjection;
using static BookingService.Tests.Infrastructure.BookingApi;

namespace BookingService.Tests.Integration;

// Doanh thu cho dashboard Admin: tiền của các thanh toán đã nhận trong khoảng thời gian
[Collection(BookingApiCollection.Name)]
public class PaymentSummaryTests
{
    private readonly BookingApiFactory _factory;
    private readonly HttpClient _admin;

    public PaymentSummaryTests(BookingApiFactory factory)
    {
        _factory = factory;
        _admin = factory.ClientFor(TestUsers.AdminToken);
    }

    [Fact]
    public async Task Summary_CountsPaidBookings_ForAdminsOnly()
    {
        var start = DateTime.Today;
        var end = DateTime.Today.AddDays(1).AddTicks(-1);
        var route = $"/api/v1/payments/summary?start={start:yyyy-MM-ddTHH:mm:ss}&end={end:yyyy-MM-ddTHH:mm:ss}";
        var before = await _admin.GetFromJsonAsync<JsonElement>(route);

        var customer = _factory.ClientFor(TestUsers.CustomerAToken);
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var bookingId = await CreatePaidBookingAsync(_factory, customer, showtime.Id, NewSeat(), NewSeat());
        var amount = (await customer.GetFromJsonAsync<JsonElement>($"/api/v1/bookings/{bookingId}"))
            .GetProperty("totalAmount").GetDecimal();

        var after = await _admin.GetFromJsonAsync<JsonElement>(route);
        Assert.Equal(before.GetProperty("paidCount").GetInt32() + 1, after.GetProperty("paidCount").GetInt32());
        Assert.Equal(before.GetProperty("revenue").GetDecimal() + amount, after.GetProperty("revenue").GetDecimal());
        Assert.Equal(after.GetProperty("revenue").GetDecimal(),
            after.GetProperty("dailyRevenue").EnumerateArray().Sum(day => day.GetProperty("revenue").GetDecimal()));

        Assert.Equal(HttpStatusCode.Forbidden,
            (await _factory.ClientFor(TestUsers.StaffToken).GetAsync(route)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await customer.GetAsync(route)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await _admin.GetAsync($"/api/v1/payments/summary?start={end:yyyy-MM-ddTHH:mm:ss}&end={start:yyyy-MM-ddTHH:mm:ss}")).StatusCode);
    }

    [Fact]
    public async Task Summary_GroupsRevenueByCreationDay_ExcludingFailedAndRefundedPayments()
    {
        var first = new DateTime(2012, 1, 15, 10, 0, 0);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<PaymentDbContext>();
        foreach (var (date, status, amount) in new[] {
            (first, "SUCCESS", 100m), (first, "REFUND_PENDING", 50m),
            (first, "FAILED", 700m), (first.AddDays(1), "REFUNDED", 30m),
            (first.AddDays(1), "SUCCESS", 200m), (first.AddDays(-1), "SUCCESS", 999m)
        })
        {
            db.Payments.Add(new Payment { PaymentCode = "DAILY-" + Guid.NewGuid().ToString("N"),
                BookingId = 900001, Amount = amount, Method = "CASH", Status = status, CreatedAt = date });
        }
        await db.SaveChangesAsync();
        var summary = await _admin.GetFromJsonAsync<JsonElement>(
            "/api/v1/payments/summary?start=2012-01-15T00:00:00&end=2012-01-16T23:59:59");
        Assert.Equal(350m, summary.GetProperty("revenue").GetDecimal());
        Assert.Equal(30m, summary.GetProperty("refundedAmount").GetDecimal());
        var days = summary.GetProperty("dailyRevenue").EnumerateArray().ToArray();
        Assert.Equal(2, days.Length);
        Assert.Equal(first.Date, days[0].GetProperty("date").GetDateTime());
        Assert.Equal(150m, days[0].GetProperty("revenue").GetDecimal());
        Assert.Equal(first.Date.AddDays(1), days[1].GetProperty("date").GetDateTime());
        Assert.Equal(200m, days[1].GetProperty("revenue").GetDecimal());
    }
}
