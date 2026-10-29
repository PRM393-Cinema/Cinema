using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AuthService.Tests.Infrastructure;

namespace AuthService.Tests.Integration;

// Người dùng tự sửa hồ sơ và đổi mật khẩu bằng mật khẩu hiện tại
[Collection(AuthApiCollection.Name)]
public class ProfileTests
{
    private readonly AuthApiFactory _factory;

    public ProfileTests(AuthApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task CustomersEditTheirNameAndPhone_ButNotWithBadValues()
    {
        var email = $"khach-{Guid.NewGuid():N}@test.local";
        var customer = await _factory.RegisterVerifiedCustomerAsync(email, "Secret@123");
        var client = _factory.ClientFor(customer.GetProperty("accessToken").GetString());

        var updated = await client.PutAsJsonAsync("/api/v1/auth/me", new { fullName = "  Trần Thị Mới  ", phone = "0912 345 678" });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        var me = await client.GetFromJsonAsync<JsonElement>("/api/v1/auth/me");
        Assert.Equal("Trần Thị Mới", me.GetProperty("fullName").GetString());
        Assert.Equal("0912 345 678", me.GetProperty("phone").GetString());
        Assert.Equal(email, me.GetProperty("email").GetString());

        // Bỏ trống số điện thoại là xoá
        var cleared = await (await client.PutAsJsonAsync("/api/v1/auth/me", new { fullName = "Trần Thị Mới", phone = "" }))
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(JsonValueKind.Null, cleared.GetProperty("phone").ValueKind);

        Assert.Equal(HttpStatusCode.BadRequest,
            (await client.PutAsJsonAsync("/api/v1/auth/me", new { fullName = "", phone = "" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await client.PutAsJsonAsync("/api/v1/auth/me", new { fullName = "Tên", phone = "123" })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await _factory.CreateClient().PutAsJsonAsync("/api/v1/auth/me", new { fullName = "Tên" })).StatusCode);
    }

    [Fact]
    public async Task ChangingThePassword_NeedsTheCurrentOne_AndSignsOutOtherDevices()
    {
        var email = $"khach-{Guid.NewGuid():N}@test.local";
        var customer = await _factory.RegisterVerifiedCustomerAsync(email, "Secret@123");
        var client = _factory.ClientFor(customer.GetProperty("accessToken").GetString());
        var otherDevice = customer.GetProperty("refreshToken").GetString();

        var wrong = await client.PostAsJsonAsync("/api/v1/auth/change-password",
            new { currentPassword = "Wrong@123", newPassword = "Newer@123" });
        Assert.Equal(HttpStatusCode.BadRequest, wrong.StatusCode);
        Assert.Contains("Current password is incorrect", await wrong.Content.ReadAsStringAsync());
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/v1/auth/change-password",
            new { currentPassword = "Secret@123", newPassword = "Secret@123" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/v1/auth/change-password",
            new { currentPassword = "Secret@123", newPassword = "123" })).StatusCode);

        var changed = await client.PostAsJsonAsync("/api/v1/auth/change-password",
            new { currentPassword = "Secret@123", newPassword = "Newer@123" });
        Assert.Equal(HttpStatusCode.OK, changed.StatusCode);
        var tokens = await changed.Content.ReadFromJsonAsync<JsonElement>();

        // Thiết bị đang dùng nhận refresh token mới; refresh token cũ (thiết bị khác) hết dùng được
        Assert.Equal(HttpStatusCode.OK, (await _factory.CreateClient().PostAsJsonAsync("/api/v1/auth/refresh",
            new { refreshToken = tokens.GetProperty("refreshToken").GetString() })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await _factory.CreateClient().PostAsJsonAsync("/api/v1/auth/refresh",
            new { refreshToken = otherDevice })).StatusCode);

        var oldLogin = await _factory.CreateClient().PostAsJsonAsync("/api/v1/auth/login",
            new { email, password = "Secret@123" });
        Assert.NotEqual(HttpStatusCode.OK, oldLogin.StatusCode);
        var newLogin = await _factory.LoginAsync(email, "Newer@123");
        Assert.False(string.IsNullOrEmpty(newLogin.GetProperty("accessToken").GetString()));
    }
}
