using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Data;
using BookingService.Models;
using BookingService.Tests.Infrastructure;

namespace BookingService.Tests.Integration;

[Collection(BookingApiCollection.Name)]
public sealed class AssistantAccountTests(BookingApiFactory factory)
{
    [Fact]
    public async Task Summary_IsOwnerScoped_AggregatesAllRows_AndUsesInclusiveDateBoundaries()
    {
        const long userId = 120001;
        var february = new DateTime(2026, 2, 1);
        await factory.ExecuteAsync<PaymentDbContext>(async db =>
        {
            for (var i = 0; i < 15; i++) db.Payments.Add(new Payment
            {
                PaymentCode = $"AI-SUMMARY-{i}", BookingId = 123, UserId = userId,
                Amount = 10, Status = "SUCCESS", Method = "PAYOS", CreatedAt = february.AddDays(i + 1)
            });
            db.Payments.AddRange(
                new Payment { PaymentCode = "AI-HIGHEST", BookingId = 123, UserId = userId, Amount = 500, Status = "REFUND_PENDING", CreatedAt = february },
                new Payment { PaymentCode = "AI-REFUND", BookingId = 123, UserId = userId, Amount = 300, Status = "REFUNDED", CreatedAt = february.AddDays(27).AddHours(23) },
                new Payment { PaymentCode = "AI-FAILED", BookingId = 123, UserId = userId, Amount = 99999, Status = "FAILED", CreatedAt = february },
                new Payment { PaymentCode = "AI-NEXT-MONTH", BookingId = 123, UserId = userId, Amount = 1000, Status = "SUCCESS", CreatedAt = february.AddMonths(1) },
                new Payment { PaymentCode = "AI-OTHER-OWNER", BookingId = 123, UserId = userId + 1, Amount = 999999, Status = "SUCCESS", CreatedAt = february });
            await db.SaveChangesAsync();
        });
        await factory.ExecuteAsync<BookingDbContext>(async db =>
        {
            for (var i = 0; i < 13; i++) db.Bookings.Add(new Booking
            {
                BookingCode = $"AI-BOOK-{i}", ShowtimeId = 1, UserId = userId, MovieTitle = "Test movie",
                Status = "CONFIRMED", TotalAmount = 10, CreatedAt = february.AddDays(i)
            });
            await db.SaveChangesAsync();
        });
        using var client = factory.ClientFor(TestJwt.Create(userId, "private@test.local", "ROLE_CUSTOMER"));
        const string path = "/api/v1/bookings/assistant-summary?from=2026-02-01&to=2026-02-28";
        var summary = await client.GetFromJsonAsync<JsonElement>(path + "&userId=120002");
        Assert.Equal(950, summary.GetProperty("grossPaid").GetDecimal());
        Assert.Equal(300, summary.GetProperty("refunded").GetDecimal());
        Assert.Equal(650, summary.GetProperty("netPaid").GetDecimal());
        Assert.Equal(18, summary.GetProperty("paymentCount").GetInt32());
        Assert.Equal(13, summary.GetProperty("bookingCount").GetInt32());
        Assert.Equal("AI-HIGHEST", summary.GetProperty("highestPaidPayment").GetProperty("paymentCode").GetString());
        Assert.Equal(10, summary.GetProperty("payments").GetArrayLength());
        Assert.Equal(10, summary.GetProperty("bookings").GetArrayLength());
        Assert.DoesNotContain("private@test.local", summary.ToString());
        Assert.DoesNotContain("AI-OTHER-OWNER", summary.ToString());
        var second = await client.GetFromJsonAsync<JsonElement>(path + "&page=2");
        Assert.Equal(8, second.GetProperty("payments").GetArrayLength());
        Assert.Equal(3, second.GetProperty("bookings").GetArrayLength());
        var search = await client.GetFromJsonAsync<JsonElement>(path + "&query=AI-HIGHEST");
        Assert.Equal(950, search.GetProperty("grossPaid").GetDecimal());
        Assert.Equal(1, search.GetProperty("matchingPayments").GetInt32());
        Assert.Equal(0, search.GetProperty("matchingBookings").GetInt32());
        using var other = factory.ClientFor(TestJwt.Create(userId + 2, "other@test.local", "ROLE_CUSTOMER"));
        var empty = await other.GetFromJsonAsync<JsonElement>(path);
        Assert.Equal(0, empty.GetProperty("grossPaid").GetDecimal());
        Assert.Equal(0, empty.GetProperty("paymentCount").GetInt32());
    }

    [Theory]
    [InlineData("?from=2026-03-01&to=2026-02-01")]
    [InlineData("?to=9999-12-31")]
    [InlineData("?page=0")]
    [InlineData("?page=10001")]
    [InlineData("?from=bad")]
    public async Task Summary_RejectsInvalidRanges(string query)
    {
        using var client = factory.ClientFor(TestUsers.CustomerAToken);
        using var response = await client.GetAsync("/api/v1/bookings/assistant-summary" + query);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Summary_RequiresAuthentication()
    {
        using var client = factory.ClientFor(null);
        using var response = await client.GetAsync("/api/v1/bookings/assistant-summary");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
