using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Data;
using BookingService.Messaging;
using BookingService.Messaging.Handlers;
using BookingService.Tests.Infrastructure;
using static BookingService.Tests.Infrastructure.BookingApi;

namespace BookingService.Tests.Integration;

// Bắp nước bán kèm vé: Admin quản lý menu, khách / quầy chọn món khi đặt vé. Giá lấy từ menu, tiền bắp nước
// nằm trong tổng tiền nên thanh toán, doanh thu và hoàn tiền tính luôn.
[Collection(BookingApiCollection.Name)]
public class ConcessionTests
{
    private readonly BookingApiFactory _factory;
    private readonly HttpClient _admin;
    private readonly HttpClient _customer;

    public ConcessionTests(BookingApiFactory factory)
    {
        _factory = factory;
        _admin = factory.ClientFor(TestUsers.AdminToken);
        _customer = factory.ClientFor(TestUsers.CustomerAToken);
    }

    [Fact]
    public async Task OnlyAdmin_ManagesTheMenu_AndCustomersSeeWhatIsSold()
    {
        var popcorn = await CreateItemAsync("Bắp thử", 55000);
        var stopped = await CreateItemAsync("Món ngừng bán", 30000, active: false);

        Assert.Equal(HttpStatusCode.Forbidden, (await _customer.PostAsJsonAsync("/api/v1/concessions",
            new { name = "X", price = 10000 })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _factory.ClientFor(TestUsers.StaffToken)
            .PutAsJsonAsync($"/api/v1/concessions/{popcorn}", new { name = "X", price = 10000 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await _admin.PostAsJsonAsync("/api/v1/concessions",
            new { name = "Quá rẻ", price = 500 })).StatusCode);

        // Khách (kể cả chưa đăng nhập) chỉ thấy món đang bán, kể cả khi xin cả món ngừng bán
        var menu = await _factory.CreateClient()
            .GetFromJsonAsync<JsonElement>("/api/v1/concessions?includeInactive=true");
        var ids = menu.EnumerateArray().Select(item => item.GetProperty("id").GetInt64()).ToList();
        Assert.Contains(popcorn, ids);
        Assert.DoesNotContain(stopped, ids);

        var all = await _admin.GetFromJsonAsync<JsonElement>("/api/v1/concessions?includeInactive=true");
        Assert.Contains(stopped, all.EnumerateArray().Select(item => item.GetProperty("id").GetInt64()));

        // Sửa giá; bỏ trống "active" thì giữ nguyên
        var updated = await _admin.PutAsJsonAsync($"/api/v1/concessions/{popcorn}",
            new { name = "Bắp thử", price = 59000 });
        var item = await updated.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(59000m, item.GetProperty("price").GetDecimal());
        Assert.True(item.GetProperty("active").GetBoolean());
    }

    [Fact]
    public async Task SnacksAreAddedToTheTotal_PricedByTheMenu_AndListedInTheTicketEmail()
    {
        var popcorn = await CreateItemAsync("Bắp rang bơ thử", 55000);
        var drink = await CreateItemAsync("Nước ngọt thử", 39000);
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));

        var response = await _customer.PostAsJsonAsync("/api/v1/bookings", new
        {
            showtimeId = showtime.Id,
            seats = new[] { new { seatId = NewSeat() } },
            concessions = new[]
            {
                new { itemId = popcorn, quantity = 2 },
                new { itemId = drink, quantity = 1 }
            }
        });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var booking = await response.Content.ReadFromJsonAsync<JsonElement>();
        var id = booking.GetProperty("id").GetInt64();

        // Ghế 90.000 (bản giả MovieService) + 2 × 55.000 + 39.000
        Assert.Equal(149000m, booking.GetProperty("concessionsAmount").GetDecimal());
        Assert.Equal(239000m, booking.GetProperty("totalAmount").GetDecimal());
        var lines = booking.GetProperty("concessions").EnumerateArray().ToList();
        Assert.Equal(2, lines.Count);
        Assert.Equal(110000m, lines[0].GetProperty("amount").GetDecimal());

        // Đổi giá menu sau khi đặt không làm đổi đơn
        await _admin.PutAsJsonAsync($"/api/v1/concessions/{popcorn}", new { name = "Bắp rang bơ thử", price = 99000 });
        var read = await _customer.GetFromJsonAsync<JsonElement>($"/api/v1/bookings/{id}");
        Assert.Equal(239000m, read.GetProperty("totalAmount").GetDecimal());
        Assert.Equal(55000m, read.GetProperty("concessions")[0].GetProperty("unitPrice").GetDecimal());

        // Trả đủ tổng tiền (kể cả bắp nước) thì vé được xác nhận; email vé có bắp nước
        var orderCode = await CheckoutOrderCodeAsync(_customer, id, 239000m);
        Assert.Equal(HttpStatusCode.OK, (await SendWebhookAsync(_factory.CreateClient(), orderCode, 239000m)).StatusCode);
        var confirmed = Assert.Single(await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingConfirmed, id));
        await _factory.HandleAsync<NotificationEventHandler>(confirmed);
        var code = read.GetProperty("bookingCode").GetString()!;
        var email = Assert.Single(_factory.Emails.To(TestUsers.CustomerA.Email), mail => mail.Subject.Contains(code));
        Assert.Contains("2 × Bắp rang bơ thử", WebUtility.HtmlDecode(email.Content));
    }

    [Fact]
    public async Task StoppedItemsOrBadQuantitiesAreRefused()
    {
        var stopped = await CreateItemAsync("Món đã ngừng", 30000, active: false);
        var popcorn = await CreateItemAsync("Bắp hợp lệ", 55000);
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));

        async Task<HttpStatusCode> BookAsync(params object[] concessions) =>
            (await _customer.PostAsJsonAsync("/api/v1/bookings", new
            {
                showtimeId = showtime.Id,
                seats = new[] { new { seatId = NewSeat() } },
                concessions
            })).StatusCode;

        Assert.Equal(HttpStatusCode.BadRequest, await BookAsync(new { itemId = stopped, quantity = 1 }));
        Assert.Equal(HttpStatusCode.BadRequest, await BookAsync(new { itemId = 999999, quantity = 1 }));
        Assert.Equal(HttpStatusCode.BadRequest, await BookAsync(new { itemId = popcorn, quantity = 21 }));
        Assert.Equal(HttpStatusCode.BadRequest,
            await BookAsync(new { itemId = popcorn, quantity = 1 }, new { itemId = popcorn, quantity = 2 }));
    }

    private async Task<long> CreateItemAsync(string name, decimal price, bool active = true)
    {
        var response = await _admin.PostAsJsonAsync("/api/v1/concessions", new { name, price, active });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetInt64();
    }
}
