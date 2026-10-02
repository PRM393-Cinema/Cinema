using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using BookingService.Helpers;

namespace BookingService.Tests.Infrastructure;

// Người dùng trong test và các thao tác API hay dùng
public static class TestUsers
{
    public static readonly (long Id, string Email) CustomerA = (101, "khach.a@test.local");
    public static readonly (long Id, string Email) CustomerB = (102, "khach.b@test.local");
    public static readonly (long Id, string Email) Staff = (201, "nhanvien@test.local");
    public static readonly (long Id, string Email) Admin = (301, "admin@test.local");

    public static string CustomerAToken => TestJwt.Create(CustomerA.Id, CustomerA.Email, "ROLE_CUSTOMER");
    public static string CustomerBToken => TestJwt.Create(CustomerB.Id, CustomerB.Email, "ROLE_CUSTOMER");
    public static string StaffToken => TestJwt.Create(Staff.Id, Staff.Email, "ROLE_STAFF");
    public static string AdminToken => TestJwt.Create(Admin.Id, Admin.Email, "ROLE_ADMIN");
}

public static class BookingApi
{
    private static long _nextSeatId = 5000;

    // Mỗi test dùng ghế riêng để các test chạy chung database không đụng nhau
    public static long NewSeat()
    {
        return Interlocked.Increment(ref _nextSeatId);
    }

    public static async Task<JsonElement> CreateBookingAsync(HttpClient client, long showtimeId, params long[] seatIds)
    {
        var response = await client.PostAsJsonAsync("/api/v1/bookings", new
        {
            userId = 0,
            showtimeId,
            seats = seatIds.Select(seatId => new { seatId })
        });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return await response.Content.ReadFromJsonAsync<JsonElement>();
    }

    public static Task<HttpResponseMessage> CheckoutAsync(HttpClient client, long bookingId, decimal amount)
    {
        return client.PostAsJsonAsync("/api/v1/payments/payos/checkout", new
        {
            bookingId,
            userId = 0,
            amount,
            returnUrl = "https://example.com/return",
            cancelUrl = "https://example.com/cancel"
        });
    }

    // Body webhook PayOS đã ký bằng checksum key (orderCode = id của booking)
    public static Task<HttpResponseMessage> SendWebhookAsync(
        HttpClient client,
        long orderCode,
        decimal amount,
        string checksumKey = BookingApiFactory.ChecksumKey,
        string code = "00")
    {
        var data = new Dictionary<string, object?>
        {
            ["orderCode"] = orderCode,
            ["amount"] = (long)amount,
            ["description"] = $"CS{orderCode}",
            ["accountNumber"] = "12345678",
            ["reference"] = $"TF{orderCode}",
            ["transactionDateTime"] = "2026-10-02 18:25:00",
            ["currency"] = "VND",
            ["paymentLinkId"] = $"link-{orderCode}",
            ["code"] = code,
            ["desc"] = "Thành công",
            ["counterAccountBankId"] = "970436",
            ["counterAccountBankName"] = "Vietcombank",
            ["counterAccountName"] = "NGUYEN VAN A",
            ["counterAccountNumber"] = "0011223344",
            ["virtualAccountName"] = null,
            ["virtualAccountNumber"] = ""
        };

        var dataElement = JsonSerializer.SerializeToElement(data);
        var body = JsonSerializer.Serialize(new
        {
            code = "00",
            desc = "success",
            success = true,
            data,
            signature = PayOsSignature.Create(dataElement, checksumKey)
        });

        return client.PostAsync(
            "/api/v1/payments/payos/webhook",
            new StringContent(body, Encoding.UTF8, "application/json"));
    }

    // Đặt vé + trả tiền qua webhook: trả về id booking đã CONFIRMED
    public static async Task<long> CreatePaidBookingAsync(
        BookingApiFactory factory,
        HttpClient customer,
        long showtimeId,
        params long[] seatIds)
    {
        var booking = await CreateBookingAsync(customer, showtimeId, seatIds);
        var bookingId = booking.GetProperty("id").GetInt64();
        var amount = booking.GetProperty("totalAmount").GetDecimal();

        Assert.Equal(HttpStatusCode.OK, (await CheckoutAsync(customer, bookingId, amount)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await SendWebhookAsync(factory.CreateClient(), bookingId, amount)).StatusCode);

        return bookingId;
    }
}
