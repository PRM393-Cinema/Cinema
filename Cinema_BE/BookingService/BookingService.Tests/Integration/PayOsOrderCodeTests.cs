using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Data;
using BookingService.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using static BookingService.Tests.Infrastructure.BookingApi;

namespace BookingService.Tests.Integration;

// Mã đơn PayOS cố định cho mỗi booking nhưng khác id booking: tài khoản PayOS dùng chung cho nhiều môi trường,
// id nhỏ đã có đơn ở DB khác nên PayOS từ chối tạo link. App vẫn xác minh được bằng id booking, và payment
// tạo trước bản này (mã đơn = id booking) vẫn dùng tiếp.
[Collection(BookingApiCollection.Name)]
public class PayOsOrderCodeTests
{
    private readonly BookingApiFactory _factory;
    private readonly HttpClient _customer;

    public PayOsOrderCodeTests(BookingApiFactory factory)
    {
        _factory = factory;
        _customer = factory.ClientFor(TestUsers.CustomerAToken);
    }

    [Fact]
    public async Task OrderCode_IsStablePerBooking_AndNotTheBookingId()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var booking = await CreateBookingAsync(_customer, showtime.Id, NewSeat());
        var id = booking.GetProperty("id").GetInt64();
        var amount = booking.GetProperty("totalAmount").GetDecimal();
        var bookingCode = booking.GetProperty("bookingCode").GetString()!;

        // id × 1.000.000 + 6 số ngẫu nhiên cuối mã vé; gọi lại trả đúng link cũ
        var orderCode = await CheckoutOrderCodeAsync(_customer, id, amount);
        Assert.Equal(id * 1_000_000 + long.Parse(bookingCode[^6..]), orderCode);
        Assert.Equal(orderCode, await CheckoutOrderCodeAsync(_customer, id, amount));
        Assert.Equal(orderCode.ToString(), await _factory.QueryAsync<PaymentDbContext, string?>(db =>
            db.Payments.Where(p => p.BookingId == id).Select(p => p.TransactionRef).SingleAsync()));

        // Đơn mang số bằng id booking là của môi trường khác: webhook của nó không đụng tới vé này
        Assert.Equal(HttpStatusCode.OK, (await SendWebhookAsync(_factory.CreateClient(), id, amount)).StatusCode);
        Assert.Equal("PENDING", await BookingStatusAsync(id));

        // Xác minh bằng mã đơn hay bằng id booking đều ra cùng payment; người khác thì không xem được
        var byOrderCode = await VerifyAsync(_customer, orderCode);
        var byBookingId = await VerifyAsync(_customer, id);
        Assert.Equal(byOrderCode.GetProperty("id").GetInt64(), byBookingId.GetProperty("id").GetInt64());
        Assert.Equal(HttpStatusCode.Forbidden, (await _factory.ClientFor(TestUsers.CustomerBToken)
            .PostAsync($"/api/v1/payments/payos/{id}/verify", null)).StatusCode);

        _factory.PayOs.Statuses[orderCode] = "PAID";
        Assert.Equal("SUCCESS", (await VerifyAsync(_customer, id)).GetProperty("status").GetString());
        Assert.Equal("CONFIRMED", await BookingStatusAsync(id));
    }

    [Fact]
    public async Task PaymentMadeWithTheOldOrderCode_IsStillReusedAndVerified()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var booking = await CreateBookingAsync(_customer, showtime.Id, NewSeat());
        var id = booking.GetProperty("id").GetInt64();
        var amount = booking.GetProperty("totalAmount").GetDecimal();

        // Link tạo trước bản này: mã đơn = id booking
        var paymentId = await _factory.QueryAsync<PaymentDbContext, long>(async db =>
        {
            var payment = new Models.Payment
            {
                PaymentCode = $"PAY-LEGACY-{id}",
                BookingId = id,
                UserId = TestUsers.CustomerA.Id,
                Amount = amount,
                Method = "PAYOS",
                Status = "PENDING",
                TransactionRef = id.ToString(),
                CreatedAt = DateTime.Now
            };
            db.Payments.Add(payment);
            await db.SaveChangesAsync();
            return payment.Id;
        });
        await _factory.QueryAsync<BookingDbContext, int>(db => db.Bookings
            .Where(b => b.Id == id)
            .ExecuteUpdateAsync(b => b.SetProperty(x => x.PaymentId, paymentId)));

        Assert.Equal(id, await CheckoutOrderCodeAsync(_customer, id, amount));

        _factory.PayOs.Statuses[id] = "PAID";
        Assert.Equal("SUCCESS", (await VerifyAsync(_customer, id)).GetProperty("status").GetString());
        Assert.Equal("CONFIRMED", await BookingStatusAsync(id));
    }

    private static async Task<JsonElement> VerifyAsync(HttpClient client, long orderCodeOrBookingId)
    {
        var response = await client.PostAsync($"/api/v1/payments/payos/{orderCodeOrBookingId}/verify", null);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return await response.Content.ReadFromJsonAsync<JsonElement>();
    }

    private Task<string> BookingStatusAsync(long id)
    {
        return _factory.QueryAsync<BookingDbContext, string>(db =>
            db.Bookings.Where(b => b.Id == id).Select(b => b.Status).SingleAsync());
    }
}
