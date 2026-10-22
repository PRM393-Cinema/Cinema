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

// Bán vé tại quầy: vé khách vãng lai không gắn tài khoản, thu tiền mặt hoặc khách quét QR chuyển khoản PayOS.
// Cả hai cách đều có payment nên doanh thu và hoàn tiền vẫn khớp.
[Collection(BookingApiCollection.Name)]
public class CounterSaleTests
{
    private readonly BookingApiFactory _factory;
    private readonly HttpClient _staff;
    private readonly HttpClient _customer;

    public CounterSaleTests(BookingApiFactory factory)
    {
        _factory = factory;
        _staff = factory.ClientFor(TestUsers.StaffToken);
        _customer = factory.ClientFor(TestUsers.CustomerAToken);
    }

    [Fact]
    public async Task WalkInPaysCash_TicketIsConfirmedEmailedAndCountedAsRevenue()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddHours(1));
        var booking = await CreateWalkInAsync(showtime.Id, phone: "0901 234 567", NewSeat(), NewSeat());
        var id = booking.GetProperty("id").GetInt64();
        var total = booking.GetProperty("totalAmount").GetDecimal();
        Assert.Equal(JsonValueKind.Null, booking.GetProperty("userId").ValueKind);
        Assert.Equal("0901 234 567", booking.GetProperty("customerPhone").GetString());
        Assert.Equal("PENDING", booking.GetProperty("status").GetString());

        var revenueRoute = $"/api/v1/payments/summary?start={DateTime.Today:yyyy-MM-ddTHH:mm:ss}" +
                           $"&end={DateTime.Today.AddDays(1).AddTicks(-1):yyyy-MM-ddTHH:mm:ss}";
        var admin = _factory.ClientFor(TestUsers.AdminToken);
        var revenueBefore = (await admin.GetFromJsonAsync<JsonElement>(revenueRoute)).GetProperty("revenue").GetDecimal();

        // Khách chưa đưa đủ tiền; khách hàng không tự thu tiền mặt được
        var tooLittle = await PayCashAsync(id, total - 1000);
        Assert.Equal(HttpStatusCode.BadRequest, tooLittle.StatusCode);
        Assert.Contains("cost", await tooLittle.Content.ReadAsStringAsync());
        Assert.Equal(HttpStatusCode.Forbidden, (await _customer.PostAsJsonAsync("/api/v1/payments/cash",
            new { bookingId = id, amountReceived = total })).StatusCode);

        var paid = await PayCashAsync(id, total + 50_000, "vanglai@test.local");
        Assert.Equal(HttpStatusCode.OK, paid.StatusCode);
        var payment = await paid.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("CASH", payment.GetProperty("method").GetString());
        Assert.Equal("SUCCESS", payment.GetProperty("status").GetString());
        Assert.Equal(total, payment.GetProperty("amount").GetDecimal());
        Assert.Equal(JsonValueKind.Null, payment.GetProperty("userId").ValueKind);

        var confirmed = await _staff.GetFromJsonAsync<JsonElement>($"/api/v1/bookings/{id}");
        Assert.Equal("CONFIRMED", confirmed.GetProperty("status").GetString());
        Assert.Equal(payment.GetProperty("id").GetInt64(), confirmed.GetProperty("paymentId").GetInt64());
        Assert.Equal("vanglai@test.local", confirmed.GetProperty("customerEmail").GetString());
        Assert.Equal(HttpStatusCode.Conflict, (await PayCashAsync(id, total)).StatusCode);

        // Email vé (kèm QR) tới email khách vừa cho
        var ticketEvent = Assert.Single(await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingConfirmed, id));
        await _factory.HandleAsync<NotificationEventHandler>(ticketEvent);
        var code = confirmed.GetProperty("bookingCode").GetString()!;
        Assert.Contains(_factory.Emails.To("vanglai@test.local"), email => email.Subject.Contains(code));

        var revenueAfter = (await admin.GetFromJsonAsync<JsonElement>(revenueRoute)).GetProperty("revenue").GetDecimal();
        Assert.Equal(revenueBefore + total, revenueAfter);

        // Không ai đăng nhập xem được vé này ngoài Staff / Admin; check-in ngay được vì suất sắp chiếu
        Assert.Equal(HttpStatusCode.Forbidden, (await _customer.GetAsync($"/api/v1/bookings/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _staff.PostAsync($"/api/v1/bookings/{id}/check-in", null)).StatusCode);
    }

    [Fact]
    public async Task WalkInWithoutContact_GetsNoEmail_AndStaffCanStillRefundIt()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var booking = await CreateWalkInAsync(showtime.Id, phone: null, NewSeat());
        var id = booking.GetProperty("id").GetInt64();
        var sentBefore = _factory.Emails.Sent.Count;

        Assert.Equal(HttpStatusCode.OK,
            (await PayCashAsync(id, booking.GetProperty("totalAmount").GetDecimal())).StatusCode);
        var ticketEvent = Assert.Single(await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingConfirmed, id));
        await _factory.HandleAsync<NotificationEventHandler>(ticketEvent);
        Assert.Equal(sentBefore, _factory.Emails.Sent.Count);

        Assert.Equal(HttpStatusCode.OK, (await _staff.PostAsync($"/api/v1/bookings/{id}/cancel?reason=Doi%20y", null)).StatusCode);
        var cancelled = Assert.Single(
            await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingCancelled, id));
        await _factory.HandleAsync<PaymentBookingEventsHandler>(cancelled);

        var refund = Assert.Single(await _factory.QueryAsync<PaymentDbContext, List<Models.Refund>>(db =>
            db.Refunds.Where(r => r.BookingId == id).ToListAsync()));
        Assert.Equal("PENDING", refund.Status);
        Assert.Null(refund.UserId);
    }

    [Fact]
    public async Task StaffShowsTransferQr_ThenCustomerPaysCashInstead_TransferLinkIsCancelled()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(1));
        var booking = await CreateWalkInAsync(showtime.Id, phone: null, NewSeat());
        var id = booking.GetProperty("id").GetInt64();
        var total = booking.GetProperty("totalAmount").GetDecimal();

        var checkout = await CounterCheckoutAsync(id, total);
        Assert.Equal(HttpStatusCode.OK, checkout.StatusCode);
        var link = await checkout.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(id, link.GetProperty("orderCode").GetInt64());
        Assert.False(string.IsNullOrEmpty(link.GetProperty("qrCode").GetString()));
        var transferPaymentId = link.GetProperty("paymentId").GetInt64();

        var cash = await PayCashAsync(id, total);
        Assert.Equal(HttpStatusCode.OK, cash.StatusCode);
        Assert.Contains(id, _factory.PayOs.CancelledLinks);
        Assert.Equal("FAILED", (await _staff.GetFromJsonAsync<JsonElement>($"/api/v1/payments/{transferPaymentId}"))
            .GetProperty("status").GetString());

        // Kiểm tra lại đơn chuyển khoản đã huỷ không làm mất vé đã trả tiền mặt
        Assert.Equal(HttpStatusCode.OK, (await _staff.PostAsync($"/api/v1/payments/payos/{id}/verify", null)).StatusCode);
        Assert.Equal("CONFIRMED", (await _staff.GetFromJsonAsync<JsonElement>($"/api/v1/bookings/{id}"))
            .GetProperty("status").GetString());
    }

    [Fact]
    public async Task TransferAlreadyArrived_CashIsRefused_AndVerifyConfirmsTheTicket()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(1));
        var booking = await CreateWalkInAsync(showtime.Id, phone: null, NewSeat());
        var id = booking.GetProperty("id").GetInt64();
        var total = booking.GetProperty("totalAmount").GetDecimal();
        Assert.Equal(HttpStatusCode.OK, (await CounterCheckoutAsync(id, total)).StatusCode);

        _factory.PayOs.Statuses[id] = "PAID";
        var cash = await PayCashAsync(id, total);
        Assert.Equal(HttpStatusCode.Conflict, cash.StatusCode);
        Assert.Contains("already paid this booking by bank transfer", await cash.Content.ReadAsStringAsync());

        // Email khách cho ở quầy được lưu vào vé
        var verified = await _staff.PostAsync($"/api/v1/payments/payos/{id}/verify?recipientEmail=chuyenkhoan@test.local", null);
        Assert.Equal("SUCCESS", (await verified.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("status").GetString());
        var confirmed = await _staff.GetFromJsonAsync<JsonElement>($"/api/v1/bookings/{id}");
        Assert.Equal("CONFIRMED", confirmed.GetProperty("status").GetString());
        Assert.Equal("chuyenkhoan@test.local", confirmed.GetProperty("customerEmail").GetString());
    }

    [Fact]
    public async Task CustomersCannotBookWithoutAccount_AndBadPhoneIsRejected()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(1));

        // Khách tự đặt: user id luôn lấy từ token
        var own = await _customer.PostAsJsonAsync("/api/v1/bookings", new
        {
            showtimeId = showtime.Id,
            seats = new[] { new { seatId = NewSeat() } }
        });
        Assert.Equal(HttpStatusCode.Created, own.StatusCode);
        Assert.Equal(TestUsers.CustomerA.Id, (await own.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("userId").GetInt64());

        var badPhone = await _staff.PostAsJsonAsync("/api/v1/bookings", new
        {
            showtimeId = showtime.Id,
            customerPhone = "call me",
            seats = new[] { new { seatId = NewSeat() } }
        });
        Assert.Equal(HttpStatusCode.BadRequest, badPhone.StatusCode);
    }

    private async Task<JsonElement> CreateWalkInAsync(long showtimeId, string? phone, params long[] seatIds)
    {
        var response = await _staff.PostAsJsonAsync("/api/v1/bookings", new
        {
            showtimeId,
            customerPhone = phone,
            seats = seatIds.Select(seatId => new { seatId })
        });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return await response.Content.ReadFromJsonAsync<JsonElement>();
    }

    private Task<HttpResponseMessage> PayCashAsync(long bookingId, decimal amountReceived, string? email = null)
    {
        return _staff.PostAsJsonAsync("/api/v1/payments/cash", new
        {
            bookingId,
            amountReceived,
            recipientEmail = email
        });
    }

    // Quầy tạo QR chuyển khoản cho vé vãng lai: Staff không gửi user id
    private Task<HttpResponseMessage> CounterCheckoutAsync(long bookingId, decimal amount)
    {
        return _staff.PostAsJsonAsync("/api/v1/payments/payos/checkout", new
        {
            bookingId,
            amount,
            returnUrl = "https://example.com/return",
            cancelUrl = "https://example.com/cancel"
        });
    }
}
