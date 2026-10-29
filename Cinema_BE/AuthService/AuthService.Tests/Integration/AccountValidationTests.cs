using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AuthService.Tests.Infrastructure;

namespace AuthService.Tests.Integration;

// Dữ liệu tài khoản sai (email, mật khẩu, họ tên, số điện thoại) bị 400 kèm lỗi theo từng trường, không tạo
// tài khoản và không gửi email. Trước đây email dài hơn cột users.email trả 500.
[Collection(AuthApiCollection.Name)]
public class AccountValidationTests
{
    private const string Password = "Secret@123";

    private readonly AuthApiFactory _factory;
    private readonly HttpClient _client;

    public AccountValidationTests(AuthApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    public static TheoryData<string, string> BadEmails => new()
    {
        { "a@", "not valid" },
        { "a b@test.local", "not valid" },
        { "abc@def", "not valid" },
        { "khach@test.l", "not valid" },
        { new string('a', 140) + "@test.local", "at most 150" }, // 151 ký tự
    };

    public static TheoryData<string, string> BadPasswords => new()
    {
        { "12345", "at least 6" },
        { new string('x', 73), "at most 72" },
        // 49 ký tự nhưng 77 byte: BCrypt sẽ bỏ phần dư
        { string.Concat(Enumerable.Repeat("mậtkhẩu", 7)), "accented" },
    };

    public static TheoryData<string> BadPhones => new()
    {
        "+++",
        "1234567",
        "abc12345678",
        "0901 234 567 890 1234",
        "09-01(23)+4567",
    };

    [Theory]
    [MemberData(nameof(BadEmails))]
    public async Task Register_WithBadEmail_Returns400AndSendsNothing(string email, string message)
    {
        await AssertFieldErrorAsync(await RegisterAsync(email, Password, "Khách", null), "Email", message);
        Assert.Empty(_factory.Emails.To(email));
    }

    [Theory]
    [MemberData(nameof(BadPasswords))]
    public async Task Register_WithBadPassword_Returns400(string password, string message)
    {
        var email = NewEmail();

        await AssertFieldErrorAsync(await RegisterAsync(email, password, "Khách", null), "Password", message);
        Assert.Empty(_factory.Emails.To(email));
    }

    [Theory]
    [MemberData(nameof(BadPhones))]
    public async Task Register_WithBadPhone_Returns400(string phone)
    {
        await AssertFieldErrorAsync(
            await RegisterAsync(NewEmail(), Password, "Khách", phone), "Phone", "8 to 15 digits");
    }

    [Fact]
    public async Task Register_WithBlankOrLongName_Returns400()
    {
        await AssertFieldErrorAsync(await RegisterAsync(NewEmail(), Password, "   ", null), "FullName", "required");
        await AssertFieldErrorAsync(
            await RegisterAsync(NewEmail(), Password, new string('N', 151), null), "FullName", "at most 150");
    }

    [Fact]
    public async Task Register_AcceptsTheLongestEmailAndAPhoneWithSeparators()
    {
        // 32 + 107 + 11 = 150 ký tự
        var email = $"{Guid.NewGuid():N}{new string('a', 107)}@test.local";

        var response = await RegisterAsync(email, Password, new string('N', 150), "+84 (90) 123-4567");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotEmpty(_factory.Emails.To(email));
    }

    [Fact]
    public async Task LoginAndPasswordReset_RejectBadEmailOrPassword()
    {
        var longEmail = new string('a', 140) + "@test.local";

        await AssertFieldErrorAsync(
            await _client.PostAsJsonAsync("/api/v1/auth/login", new { email = longEmail, password = Password }),
            "Email", "at most 150");
        await AssertFieldErrorAsync(
            await _client.PostAsJsonAsync("/api/v1/auth/login", new { email = "a b@test.local", password = Password }),
            "Email", "not valid");
        await AssertFieldErrorAsync(
            await _client.PostAsJsonAsync("/api/v1/auth/forgot-password", new { email = "abc@def" }),
            "Email", "not valid");
        await AssertFieldErrorAsync(
            await _client.PostAsJsonAsync("/api/v1/auth/reset-password",
                new { email = NewEmail(), otp = "123456", newPassword = new string('x', 73) }),
            "NewPassword", "at most 72");
    }

    [Fact]
    public async Task AdminCreatingAnAccount_FollowsTheSameRules()
    {
        var admin = _factory.ClientFor(await _factory.AdminTokenAsync());

        var response = await admin.PostAsJsonAsync("/api/v1/auth/users", new
        {
            email = new string('a', 140) + "@test.local",
            password = "12345",
            fullName = "Nhân viên",
            phone = "+++",
            roles = new[] { "ROLE_STAFF" }
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        AssertFieldError(body, "Email", "at most 150");
        AssertFieldError(body, "Password", "at least 6");
        AssertFieldError(body, "Phone", "8 to 15 digits");
    }

    private static string NewEmail()
    {
        return $"user-{Guid.NewGuid():N}@test.local";
    }

    private Task<HttpResponseMessage> RegisterAsync(string email, string password, string fullName, string? phone)
    {
        return _client.PostAsJsonAsync("/api/v1/auth/register", new { email, password, fullName, phone });
    }

    private static async Task AssertFieldErrorAsync(HttpResponseMessage response, string field, string message)
    {
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        AssertFieldError(await response.Content.ReadFromJsonAsync<JsonElement>(), field, message);
    }

    private static void AssertFieldError(JsonElement body, string field, string message)
    {
        var errors = body.GetProperty("errors").GetProperty(field).EnumerateArray()
            .Select(error => error.GetString() ?? string.Empty)
            .ToList();

        Assert.Contains(errors, error => error.Contains(message, StringComparison.OrdinalIgnoreCase));
    }
}
