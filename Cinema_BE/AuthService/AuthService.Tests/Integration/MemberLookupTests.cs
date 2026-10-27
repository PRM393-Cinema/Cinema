using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AuthService.Tests.Infrastructure;

namespace AuthService.Tests.Integration;

// Quầy bán vé tìm khách hàng theo số điện thoại (tích điểm thành viên)
[Collection(AuthApiCollection.Name)]
public class MemberLookupTests
{
    private readonly AuthApiFactory _factory;

    public MemberLookupTests(AuthApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task StaffFindCustomersByPhone_IgnoringSeparators()
    {
        var admin = _factory.ClientFor(await _factory.AdminTokenAsync());
        var phone = "09" + Random.Shared.Next(10_000_000, 99_999_999);
        var spaced = $"{phone[..4]} {phone[4..7]} {phone[7..]}";

        async Task<long> CreateAsync(string role, string phoneNumber)
        {
            var created = await admin.PostAsJsonAsync("/api/v1/auth/users", new
            {
                email = $"{role}-{Guid.NewGuid():N}@test.local",
                password = "Secret@123",
                fullName = "Thành Viên Test",
                phone = phoneNumber,
                roles = new[] { role }
            });
            Assert.Equal(HttpStatusCode.Created, created.StatusCode);
            return (await created.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("userId").GetInt64();
        }

        var customer = await CreateAsync("customer", spaced);
        await CreateAsync("staff", phone); // nhân viên trùng số không hiện

        var staffEmail = $"staff-{Guid.NewGuid():N}@test.local";
        await admin.PostAsJsonAsync("/api/v1/auth/users", new
        {
            email = staffEmail,
            password = "Staff@123",
            fullName = "Nhân Viên Quầy",
            roles = new[] { "staff" }
        });
        var staff = _factory.ClientFor(
            (await _factory.LoginAsync(staffEmail, "Staff@123")).GetProperty("accessToken").GetString());

        var found = await staff.GetFromJsonAsync<JsonElement>($"/api/v1/auth/members?phone={phone[..3]}.{phone[3..]}");
        var member = Assert.Single(found.EnumerateArray());
        Assert.Equal(customer, member.GetProperty("userId").GetInt64());
        Assert.Equal(spaced, member.GetProperty("phone").GetString());

        Assert.Empty((await staff.GetFromJsonAsync<JsonElement>("/api/v1/auth/members?phone=0911111111")).EnumerateArray());
        Assert.Equal(HttpStatusCode.BadRequest, (await staff.GetAsync("/api/v1/auth/members?phone=123")).StatusCode);

        // Khách hàng không tra cứu được người khác
        var other = await _factory.RegisterVerifiedCustomerAsync($"khach-{Guid.NewGuid():N}@test.local", "Secret@123");
        Assert.Equal(HttpStatusCode.Forbidden, (await _factory.ClientFor(other.GetProperty("accessToken").GetString())
            .GetAsync($"/api/v1/auth/members?phone={phone}")).StatusCode);
    }
}
