using System.Net;
using BookingService.Tests.Infrastructure;
using static BookingService.Tests.Infrastructure.BookingApi;

namespace BookingService.Tests.Integration;

// SRS §8.3, §18 (Security test): 401 khi thiếu / sai / hết hạn token, 403 khi không đủ quyền
[Collection(BookingApiCollection.Name)]
public class AuthorizationTests
{
    private readonly BookingApiFactory _factory;

    public AuthorizationTests(BookingApiFactory factory)
    {
        _factory = factory;
    }

    [Theory]
    [InlineData("/api/v1/bookings/1")]
    [InlineData("/api/v1/payments/1")]
    [InlineData("/api/v1/payments/refunds")]
    [InlineData("/api/v1/notifications/user/1")]
    public async Task ProtectedEndpoints_WithoutToken_Return401(string url)
    {
        var response = await _factory.ClientFor(null).GetAsync(url);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ForgedExpiredOrMalformedToken_Returns401()
    {
        var forged = TestJwt.Create(301, "admin@test.local", "ROLE_ADMIN",
            secretKey: "a-different-secret-key-that-is-long-enough-123");
        var expired = TestJwt.Create(301, "admin@test.local", "ROLE_ADMIN",
            lifetime: TimeSpan.FromMinutes(-5));

        foreach (var token in new[] { forged, expired, "not-a-jwt" })
        {
            var response = await _factory.ClientFor(token).GetAsync("/api/v1/bookings");
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        }
    }

    [Theory]
    [InlineData("/api/v1/bookings")]
    [InlineData("/api/v1/payments")]
    [InlineData("/api/v1/payments/refunds")]
    public async Task StaffEndpoints_RejectCustomer_AllowStaff(string url)
    {
        Assert.Equal(HttpStatusCode.Forbidden,
            (await _factory.ClientFor(TestUsers.CustomerAToken).GetAsync(url)).StatusCode);
        Assert.Equal(HttpStatusCode.OK,
            (await _factory.ClientFor(TestUsers.StaffToken).GetAsync(url)).StatusCode);
    }

    [Fact]
    public async Task Customer_OnlySeesOwnBookingPaymentsAndHistory()
    {
        var customerA = _factory.ClientFor(TestUsers.CustomerAToken);
        var customerB = _factory.ClientFor(TestUsers.CustomerBToken);
        var staff = _factory.ClientFor(TestUsers.StaffToken);
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(3));

        var booking = await CreateBookingAsync(customerA, showtime.Id, NewSeat());
        var id = booking.GetProperty("id").GetInt64();

        Assert.Equal(HttpStatusCode.OK, (await customerA.GetAsync($"/api/v1/bookings/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await customerB.GetAsync($"/api/v1/bookings/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await staff.GetAsync($"/api/v1/bookings/{id}")).StatusCode);

        Assert.Equal(HttpStatusCode.OK, (await customerA.GetAsync($"/api/v1/payments/booking/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await customerB.GetAsync($"/api/v1/payments/booking/{id}")).StatusCode);

        Assert.Equal(HttpStatusCode.Forbidden,
            (await customerB.GetAsync($"/api/v1/bookings/user/{TestUsers.CustomerA.Id}")).StatusCode);
    }

    [Fact]
    public async Task Customer_CannotConfirmOrRefund()
    {
        var customer = _factory.ClientFor(TestUsers.CustomerAToken);

        Assert.Equal(HttpStatusCode.Forbidden,
            (await customer.PostAsync("/api/v1/bookings/1/confirm?paymentMethod=CASH", null)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await customer.PostAsync("/api/v1/payments/1/refund", null)).StatusCode);
    }

    [Fact]
    public async Task Notifications_AdminSeesAll_StaffOnlyOwn()
    {
        var staff = _factory.ClientFor(TestUsers.StaffToken);
        var admin = _factory.ClientFor(TestUsers.AdminToken);

        Assert.Equal(HttpStatusCode.Forbidden, (await staff.GetAsync("/api/v1/notifications")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await admin.GetAsync("/api/v1/notifications")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await staff.GetAsync($"/api/v1/notifications/user/{TestUsers.CustomerA.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.OK,
            (await staff.GetAsync($"/api/v1/notifications/user/{TestUsers.Staff.Id}")).StatusCode);
    }
}
