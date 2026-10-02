using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AuthService.Tests.Infrastructure;

namespace AuthService.Tests.Integration;

// Đăng ký -> OTP -> đăng nhập -> JWT (SRS FR-AUTH-01..06, tiêu chí 1)
[Collection(AuthApiCollection.Name)]
public class AuthFlowTests
{
    private const string Password = "Secret@123";

    private readonly AuthApiFactory _factory;
    private readonly HttpClient _client;

    public AuthFlowTests(AuthApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    private static string NewEmail()
    {
        return $"user-{Guid.NewGuid():N}@test.local";
    }

    [Fact]
    public async Task Register_VerifyOtp_ThenLoginAndReadProfile()
    {
        var email = NewEmail();

        var register = await _client.PostAsJsonAsync("/api/v1/auth/register",
            new { email, password = Password, fullName = "Khách Mới", phone = "0900000001" });
        Assert.Equal(HttpStatusCode.OK, register.StatusCode);

        // Chưa nhập OTP thì chưa đăng nhập được
        var early = await _client.PostAsJsonAsync("/api/v1/auth/login", new { email, password = Password });
        Assert.Equal(HttpStatusCode.Forbidden, early.StatusCode);

        var verify = await _client.PostAsJsonAsync("/api/v1/auth/verify-email",
            new { email, otp = _factory.Emails.LatestOtp(email), password = Password });
        Assert.Equal(HttpStatusCode.OK, verify.StatusCode);

        var auth = await verify.Content.ReadFromJsonAsync<JsonElement>();
        var roles = auth.GetProperty("user").GetProperty("roles").EnumerateArray().Select(r => r.GetString());
        Assert.Contains("ROLE_CUSTOMER", roles);

        var me = await _factory.ClientFor(auth.GetProperty("accessToken").GetString())
            .GetFromJsonAsync<JsonElement>("/api/v1/auth/me");
        Assert.Equal(email, me.GetProperty("email").GetString());

        var login = await _client.PostAsJsonAsync("/api/v1/auth/login", new { email, password = Password });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
    }

    [Fact]
    public async Task Login_WithWrongPasswordOrUnknownEmail_Returns401()
    {
        var wrongPassword = await _client.PostAsJsonAsync("/api/v1/auth/login",
            new { email = AuthApiFactory.AdminEmail, password = "wrong-password" });
        var unknownEmail = await _client.PostAsJsonAsync("/api/v1/auth/login",
            new { email = NewEmail(), password = Password });

        Assert.Equal(HttpStatusCode.Unauthorized, wrongPassword.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, unknownEmail.StatusCode);
    }

    [Fact]
    public async Task VerifyEmail_LocksOtpAfterTooManyWrongAttempts()
    {
        var email = NewEmail();
        (await _client.PostAsJsonAsync("/api/v1/auth/register",
            new { email, password = Password, fullName = "Khách", phone = "0900000002" })).EnsureSuccessStatusCode();

        var otp = _factory.Emails.LatestOtp(email);
        var wrong = otp == "000000" ? "111111" : "000000";

        for (var i = 0; i < 5; i++)
        {
            var attempt = await _client.PostAsJsonAsync("/api/v1/auth/verify-email",
                new { email, otp = wrong, password = Password });
            Assert.Equal(HttpStatusCode.BadRequest, attempt.StatusCode);
        }

        // Hết lượt: mã đúng cũng không dùng được nữa, phải xin mã mới
        var correct = await _client.PostAsJsonAsync("/api/v1/auth/verify-email",
            new { email, otp, password = Password });
        Assert.Equal(HttpStatusCode.BadRequest, correct.StatusCode);
    }

    [Fact]
    public async Task RefreshToken_IsRotated_AndLogoutRevokesIt()
    {
        var login = await _factory.LoginAsync(AuthApiFactory.AdminEmail, AuthApiFactory.AdminPassword);
        var firstRefresh = login.GetProperty("refreshToken").GetString();

        var refreshed = await _client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = firstRefresh });
        Assert.Equal(HttpStatusCode.OK, refreshed.StatusCode);
        var tokens = await refreshed.Content.ReadFromJsonAsync<JsonElement>();

        // Refresh token cũ đã bị thu hồi khi cấp token mới
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await _client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = firstRefresh })).StatusCode);

        var secondRefresh = tokens.GetProperty("refreshToken").GetString();
        var logout = await _factory.ClientFor(tokens.GetProperty("accessToken").GetString())
            .PostAsJsonAsync("/api/v1/auth/logout", new { refreshToken = secondRefresh });
        Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);

        Assert.Equal(HttpStatusCode.Unauthorized,
            (await _client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = secondRefresh })).StatusCode);
    }

    [Fact]
    public async Task Profile_RejectsMissingForgedOrExpiredToken()
    {
        var forged = TestJwt.Create(1, AuthApiFactory.AdminEmail, "ROLE_ADMIN",
            secretKey: "a-different-secret-key-that-is-long-enough-123");
        var expired = TestJwt.Create(1, AuthApiFactory.AdminEmail, "ROLE_ADMIN", lifetime: TimeSpan.FromMinutes(-5));

        foreach (var token in new[] { null, forged, expired })
        {
            var response = await _factory.ClientFor(token).GetAsync("/api/v1/auth/me");
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        }
    }
}
