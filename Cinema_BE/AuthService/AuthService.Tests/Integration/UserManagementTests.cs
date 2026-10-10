using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AuthService.Tests.Infrastructure;

namespace AuthService.Tests.Integration;

// Admin quản lý tài khoản (FR-AUTH-01, ma trận quyền "Manage users/roles")
[Collection(AuthApiCollection.Name)]
public class UserManagementTests
{
    private readonly AuthApiFactory _factory;

    public UserManagementTests(AuthApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task OnlyAdmin_CanListUsers()
    {
        var customer = await _factory.RegisterVerifiedCustomerAsync(
            $"khach-{Guid.NewGuid():N}@test.local", "Secret@123");
        var customerToken = customer.GetProperty("accessToken").GetString();

        Assert.Equal(HttpStatusCode.Forbidden,
            (await _factory.ClientFor(customerToken).GetAsync("/api/v1/auth/users")).StatusCode);

        var admin = _factory.ClientFor(await _factory.AdminTokenAsync());
        var users = await admin.GetFromJsonAsync<JsonElement>("/api/v1/auth/users?size=1000");

        // Phân trang tối đa 50 bản ghi
        Assert.Equal(50, users.GetProperty("pageSize").GetInt32());
        Assert.True(users.GetProperty("totalCount").GetInt32() >= 2);
    }

    [Fact]
    public async Task AdminCreatesStaff_StaffCanLoginWithoutOtp()
    {
        var admin = _factory.ClientFor(await _factory.AdminTokenAsync());
        var email = $"staff-{Guid.NewGuid():N}@test.local";

        var created = await admin.PostAsJsonAsync("/api/v1/auth/users", new
        {
            email,
            password = "Staff@123",
            fullName = "Nhân Viên Test",
            roles = new[] { "staff" }
        });

        Assert.Equal(HttpStatusCode.Created, created.StatusCode);

        var login = await _factory.LoginAsync(email, "Staff@123");
        var roles = login.GetProperty("user").GetProperty("roles").EnumerateArray().Select(r => r.GetString());
        Assert.Contains("ROLE_STAFF", roles);

        var duplicate = await admin.PostAsJsonAsync("/api/v1/auth/users", new
        {
            email,
            password = "Staff@123",
            fullName = "Trùng email",
            roles = new[] { "staff" }
        });
        Assert.Equal(HttpStatusCode.BadRequest, duplicate.StatusCode);
    }

    [Fact]
    public async Task LockedUser_CannotUseExistingTokenLoginOrRefresh_AndAdminCannotLockSelf()
    {
        var adminToken = await _factory.AdminTokenAsync();
        var admin = _factory.ClientFor(adminToken);
        var email = $"khach-{Guid.NewGuid():N}@test.local";

        var customer = await _factory.RegisterVerifiedCustomerAsync(email, "Secret@123");
        var userId = customer.GetProperty("user").GetProperty("userId").GetInt64();
        var refreshToken = customer.GetProperty("refreshToken").GetString();
        var customerClient = _factory.ClientFor(customer.GetProperty("accessToken").GetString());
        Assert.Equal(HttpStatusCode.OK, (await customerClient.GetAsync("/api/v1/auth/me")).StatusCode);

        var locked = await admin.PatchAsJsonAsync($"/api/v1/auth/users/{userId}/status", new { enabled = false });
        Assert.Equal(HttpStatusCode.OK, locked.StatusCode);

        var rejected = await customerClient.GetAsync("/api/v1/auth/me");
        Assert.Equal(HttpStatusCode.Forbidden, rejected.StatusCode);
        var problem = await rejected.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("ACCOUNT_LOCKED", problem.GetProperty("errorCode").GetString());

        Assert.Equal(HttpStatusCode.Unauthorized, (await _factory.CreateClient()
            .PostAsJsonAsync("/api/v1/auth/login", new { email, password = "Secret@123" })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await _factory.CreateClient()
            .PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken })).StatusCode);

        Assert.Equal(HttpStatusCode.OK, (await admin.PatchAsJsonAsync(
            $"/api/v1/auth/users/{userId}/status", new { enabled = true })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await customerClient.GetAsync("/api/v1/auth/me")).StatusCode);

        var me = await admin.GetFromJsonAsync<JsonElement>("/api/v1/auth/me");
        var selfLock = await admin.PatchAsJsonAsync(
            $"/api/v1/auth/users/{me.GetProperty("userId").GetInt64()}/status", new { enabled = false });
        Assert.Equal(HttpStatusCode.BadRequest, selfLock.StatusCode);
    }

    [Theory]
    [InlineData("staff", "ROLE_STAFF")]
    [InlineData("admin", "ROLE_ADMIN")]
    public async Task ChangingRoles_RevokesOldRefreshToken_ButSavingSameRolesKeepsSession(string role, string roleName)
    {
        var admin = _factory.ClientFor(await _factory.AdminTokenAsync());
        var email = $"role-{Guid.NewGuid():N}@test.local";
        var customer = await _factory.RegisterVerifiedCustomerAsync(email, "Secret@123");
        var userId = customer.GetProperty("user").GetProperty("userId").GetInt64();
        var oldRefreshToken = customer.GetProperty("refreshToken").GetString();

        var changed = await admin.PutAsJsonAsync($"/api/v1/auth/users/{userId}/roles", new { roles = new[] { role } });
        Assert.Equal(HttpStatusCode.OK, changed.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await _factory.CreateClient()
            .PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = oldRefreshToken })).StatusCode);

        var login = await _factory.LoginAsync(email, "Secret@123");
        Assert.Equal(roleName, login.GetProperty("user").GetProperty("roles")[0].GetString());
        var refreshToken = login.GetProperty("refreshToken").GetString();
        Assert.Equal(HttpStatusCode.OK, (await admin.PutAsJsonAsync(
            $"/api/v1/auth/users/{userId}/roles", new { roles = new[] { role } })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _factory.CreateClient()
            .PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken })).StatusCode);
    }
}
