using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Data;
using BookingService.Messaging;
using BookingService.Messaging.Handlers;
using BookingService.Tests.Infrastructure;
using static BookingService.Tests.Infrastructure.BookingApi;

namespace BookingService.Tests.Integration;

// Khuyến mãi giảm tiền vé: mã voucher khách nhập hoặc khuyến mãi tự áp dụng. Chỉ giảm tiền vé (không giảm
// bắp nước), một khuyến mãi mỗi đơn, lượt dùng đếm khi vé đã thanh toán.
// Khuyến mãi tự áp dụng trong test cần từ 8 vé và được tắt cuối test để không làm đổi tổng tiền của test khác.
[Collection(BookingApiCollection.Name)]
public class PromotionTests
{
    private readonly BookingApiFactory _factory;
    private readonly HttpClient _admin;
    private readonly HttpClient _customer;

    public PromotionTests(BookingApiFactory factory)
    {
        _factory = factory;
        _admin = factory.ClientFor(TestUsers.AdminToken);
        _customer = factory.ClientFor(TestUsers.CustomerAToken);
    }

    [Fact]
    public async Task OnlyAdmin_ManagesPromotions_AndCustomersOnlySeeRunningDeals()
    {
        var code = NewCode();
        var voucher = await CreateAsync(new { code, name = "Voucher thử", discountType = "PERCENT", discountValue = 10 });
        var deal = await CreateAsync(new { name = "Ưu đãi thử", discountType = "AMOUNT", discountValue = 20000, minTickets = 8 });
        try
        {
            Assert.Equal(HttpStatusCode.Forbidden, (await _customer.PostAsJsonAsync("/api/v1/promotions",
                new { name = "X", discountType = "PERCENT", discountValue = 10 })).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest, (await _admin.PostAsJsonAsync("/api/v1/promotions",
                new { name = "Quá nhiều", discountType = "PERCENT", discountValue = 95 })).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest, (await _admin.PostAsJsonAsync("/api/v1/promotions",
                new { name = "Sai ngày", discountType = "PERCENT", discountValue = 10, daysOfWeek = new[] { 8 } })).StatusCode);
            Assert.Equal(HttpStatusCode.Conflict, (await _admin.PostAsJsonAsync("/api/v1/promotions",
                new { code = code.ToLowerInvariant(), name = "Trùng mã", discountType = "AMOUNT", discountValue = 10000 })).StatusCode);

            // Khách (kể cả chưa đăng nhập) chỉ thấy khuyến mãi tự áp dụng đang chạy, không thấy mã voucher
            var shown = await _factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/v1/promotions?all=true");
            var ids = shown.EnumerateArray().Select(item => item.GetProperty("id").GetInt64()).ToList();
            Assert.Contains(deal, ids);
            Assert.DoesNotContain(voucher, ids);

            var all = await _admin.GetFromJsonAsync<JsonElement>("/api/v1/promotions?all=true");
            Assert.Contains(voucher, all.EnumerateArray().Select(item => item.GetProperty("id").GetInt64()));

            // Tắt khuyến mãi thì khách không còn thấy
            await DeactivateAsync(deal);
            shown = await _factory.CreateClient().GetFromJsonAsync<JsonElement>("/api/v1/promotions");
            Assert.DoesNotContain(deal, shown.EnumerateArray().Select(item => item.GetProperty("id").GetInt64()));
        }
        finally
        {
            await DeactivateAsync(deal);
        }
    }

    [Fact]
    public async Task AVoucherDiscountsTheTickets_NotTheSnacks_AndIsCountedOncePaid()
    {
        var code = NewCode();
        var voucher = await CreateAsync(new
        {
            code,
            name = "Giảm 10%",
            discountType = "PERCENT",
            discountValue = 10,
            maxDiscount = 15000,
            minTickets = 2,
            usageLimit = 1
        });
        var popcorn = await CreateSnackAsync("Bắp cho khuyến mãi", 55000);
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));

        // Một vé chưa đủ điều kiện; mã không có thì báo sai
        var quote = await _customer.PostAsJsonAsync("/api/v1/promotions/quote",
            new { showtimeId = showtime.Id, ticketAmount = 90000, tickets = 1, code });
        Assert.Equal(HttpStatusCode.BadRequest, quote.StatusCode);
        Assert.Contains("at least 2 tickets", await quote.Content.ReadAsStringAsync());
        Assert.Equal(HttpStatusCode.BadRequest, (await _customer.PostAsJsonAsync("/api/v1/promotions/quote",
            new { showtimeId = showtime.Id, ticketAmount = 180000, tickets = 2, code = "NO-SUCH-CODE" })).StatusCode);

        // 2 vé 180.000: 10% = 18.000 nhưng trần 15.000. Mã nhập chữ thường vẫn nhận
        var preview = await (await _customer.PostAsJsonAsync("/api/v1/promotions/quote",
            new { showtimeId = showtime.Id, ticketAmount = 180000, tickets = 2, code = code.ToLowerInvariant() }))
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(15000m, preview.GetProperty("discount").GetDecimal());
        Assert.Equal(voucher, preview.GetProperty("promotionId").GetInt64());

        var response = await _customer.PostAsJsonAsync("/api/v1/bookings", new
        {
            showtimeId = showtime.Id,
            seats = new[] { new { seatId = NewSeat() }, new { seatId = NewSeat() } },
            promotionCode = $" {code.ToLowerInvariant()} ",
            concessions = new[] { new { itemId = popcorn, quantity = 1 } }
        });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var booking = await response.Content.ReadFromJsonAsync<JsonElement>();
        var id = booking.GetProperty("id").GetInt64();

        // 180.000 − 15.000 + 55.000 bắp (bắp không được giảm)
        Assert.Equal(15000m, booking.GetProperty("discountAmount").GetDecimal());
        Assert.Equal(220000m, booking.GetProperty("totalAmount").GetDecimal());
        Assert.Equal(code, booking.GetProperty("promotionCode").GetString());
        Assert.Equal("Giảm 10%", booking.GetProperty("promotionName").GetString());

        // Chưa thanh toán thì chưa tính lượt
        Assert.Equal(0, (await GetAsync(voucher)).GetProperty("usedCount").GetInt32());

        var orderCode = await CheckoutOrderCodeAsync(_customer, id, 220000m);
        Assert.Equal(HttpStatusCode.OK, (await SendWebhookAsync(_factory.CreateClient(), orderCode, 220000m)).StatusCode);
        Assert.Equal(1, (await GetAsync(voucher)).GetProperty("usedCount").GetInt32());

        // Email vé có dòng giảm giá
        var confirmed = Assert.Single(await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingConfirmed, id));
        await _factory.HandleAsync<NotificationEventHandler>(confirmed);
        var bookingCode = booking.GetProperty("bookingCode").GetString()!;
        var email = Assert.Single(_factory.Emails.To(TestUsers.CustomerA.Email), mail => mail.Subject.Contains(bookingCode));
        var content = WebUtility.HtmlDecode(email.Content);
        Assert.Contains("Giảm giá:", content);
        Assert.Contains("(Giảm 10%)", content);

        // Hết lượt: đơn sau dùng mã bị từ chối
        var again = await _factory.ClientFor(TestUsers.CustomerBToken).PostAsJsonAsync("/api/v1/bookings", new
        {
            showtimeId = showtime.Id,
            seats = new[] { new { seatId = NewSeat() }, new { seatId = NewSeat() } },
            promotionCode = code
        });
        Assert.Equal(HttpStatusCode.BadRequest, again.StatusCode);
        Assert.Contains("fully used", await again.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task TheBestAutomaticDealApplies_OnlyOnItsDays_AndAVoucherReplacesIt()
    {
        var tuesday = NextIsoDay(2);
        var group = await CreateAsync(new
        {
            name = "Nhóm đông", discountType = "AMOUNT", discountValue = 50000, minTickets = 8
        });
        var tuesdayDeal = await CreateAsync(new
        {
            name = "Thứ Ba thử", discountType = "PERCENT", discountValue = 20, minTickets = 8, daysOfWeek = new[] { 2 }
        });
        var code = NewCode();
        await CreateAsync(new { code, name = "Mã 30K", discountType = "AMOUNT", discountValue = 30000 });
        try
        {
            async Task<JsonElement> BookAsync(DateTime start, int seats, string? promotionCode = null)
            {
                var showtime = _factory.Showtimes.AddShowtime(start);
                var response = await _customer.PostAsJsonAsync("/api/v1/bookings", new
                {
                    showtimeId = showtime.Id,
                    seats = Enumerable.Range(0, seats).Select(_ => new { seatId = NewSeat() }).ToArray(),
                    promotionCode
                });
                Assert.Equal(HttpStatusCode.Created, response.StatusCode);
                return await response.Content.ReadFromJsonAsync<JsonElement>();
            }

            // Thứ Ba, 8 vé 720.000: 20% = 144.000 nhiều hơn 50.000
            var onTuesday = await BookAsync(tuesday, 8);
            Assert.Equal(144000m, onTuesday.GetProperty("discountAmount").GetDecimal());
            Assert.Equal(576000m, onTuesday.GetProperty("totalAmount").GetDecimal());
            Assert.Equal("Thứ Ba thử", onTuesday.GetProperty("promotionName").GetString());
            Assert.Equal(JsonValueKind.Null, onTuesday.GetProperty("promotionCode").ValueKind);

            // Thứ Tư chỉ còn ưu đãi 50.000
            var onWednesday = await BookAsync(tuesday.AddDays(1), 8);
            Assert.Equal(50000m, onWednesday.GetProperty("discountAmount").GetDecimal());

            // Ít vé thì không có khuyến mãi tự áp dụng
            var few = await BookAsync(tuesday, 2);
            Assert.Equal(0m, few.GetProperty("discountAmount").GetDecimal());
            Assert.Equal(180000m, few.GetProperty("totalAmount").GetDecimal());

            // Nhập mã thì dùng mã thay cho ưu đãi tự áp dụng (mỗi đơn một khuyến mãi)
            var withCode = await BookAsync(tuesday, 8, code);
            Assert.Equal(30000m, withCode.GetProperty("discountAmount").GetDecimal());
            Assert.Equal(code, withCode.GetProperty("promotionCode").GetString());
        }
        finally
        {
            await DeactivateAsync(group);
            await DeactivateAsync(tuesdayDeal);
        }
    }

    private static string NewCode() => "T" + Guid.NewGuid().ToString("N")[..8].ToUpperInvariant();

    // Ngày gần nhất (từ ngày mai) có thứ isoDay: 1 = thứ Hai ... 7 = Chủ nhật
    private static DateTime NextIsoDay(int isoDay)
    {
        var date = DateTime.Today.AddDays(1).AddHours(19);
        while (((int)date.DayOfWeek + 6) % 7 + 1 != isoDay)
        {
            date = date.AddDays(1);
        }

        return date;
    }

    private async Task<long> CreateAsync(object promotion)
    {
        var response = await _admin.PostAsJsonAsync("/api/v1/promotions", promotion);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetInt64();
    }

    private async Task<JsonElement> GetAsync(long id)
    {
        var all = await _admin.GetFromJsonAsync<JsonElement>("/api/v1/promotions?all=true");
        return all.EnumerateArray().Single(item => item.GetProperty("id").GetInt64() == id);
    }

    private async Task DeactivateAsync(long id)
    {
        var promotion = await GetAsync(id);
        var response = await _admin.PutAsJsonAsync($"/api/v1/promotions/{id}", new
        {
            code = promotion.GetProperty("code").GetString(),
            name = promotion.GetProperty("name").GetString(),
            discountType = promotion.GetProperty("discountType").GetString(),
            discountValue = promotion.GetProperty("discountValue").GetDecimal(),
            minTickets = promotion.GetProperty("minTickets").GetInt32(),
            daysOfWeek = promotion.GetProperty("daysOfWeek").EnumerateArray().Select(day => day.GetInt32()).ToArray(),
            active = false
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    private async Task<long> CreateSnackAsync(string name, decimal price)
    {
        var response = await _admin.PostAsJsonAsync("/api/v1/concessions", new { name, price });
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetInt64();
    }
}
