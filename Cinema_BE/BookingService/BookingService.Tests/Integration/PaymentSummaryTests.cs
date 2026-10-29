using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Tests.Infrastructure;
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

        Assert.Equal(HttpStatusCode.Forbidden,
            (await _factory.ClientFor(TestUsers.StaffToken).GetAsync(route)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await customer.GetAsync(route)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await _admin.GetAsync($"/api/v1/payments/summary?start={end:yyyy-MM-ddTHH:mm:ss}&end={start:yyyy-MM-ddTHH:mm:ss}")).StatusCode);
    }
}
