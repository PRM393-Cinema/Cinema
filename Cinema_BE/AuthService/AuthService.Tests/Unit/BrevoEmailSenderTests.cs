using System.Net;
using System.Text.Json;
using AuthService.Configuration;
using AuthService.DTOs;
using AuthService.Service;
using Microsoft.Extensions.Options;

namespace AuthService.Tests.Unit;

public class BrevoEmailSenderTests
{
    private static readonly EmailMessage Otp = new()
    {
        RecipientEmail = "khach@test.local",
        Subject = "Mã xác thực email",
        HtmlContent = "<p>Mã OTP: <strong>123456</strong></p>",
        TextContent = "Mã OTP: 123456"
    };

    // Brevo giả: ghi lại request và trả [status]
    private sealed class FakeBrevo(HttpStatusCode status, string body = """{"messageId":"<1@brevo>"}""")
        : HttpMessageHandler
    {
        public HttpRequestMessage? Request { get; private set; }

        public JsonElement Payload { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            Request = request;
            Payload = JsonDocument.Parse(await request.Content!.ReadAsStringAsync(cancellationToken)).RootElement;
            return new HttpResponseMessage(status) { Content = new StringContent(body) };
        }
    }

    private static BrevoEmailSender Sender(FakeBrevo brevo, string fromEmail = "rap@test.local")
    {
        var options = new BrevoOptions { ApiKey = "test-key", FromEmail = fromEmail };
        var client = new HttpClient(brevo) { BaseAddress = new Uri(options.BaseUrl) };
        return new BrevoEmailSender(client, Options.Create(options));
    }

    [Fact]
    public async Task SendsTheEmailToBrevoWithTheApiKey()
    {
        var brevo = new FakeBrevo(HttpStatusCode.Created);

        await Sender(brevo).SendAsync(Otp);

        Assert.Equal(HttpMethod.Post, brevo.Request!.Method);
        Assert.Equal("https://api.brevo.com/v3/smtp/email", brevo.Request.RequestUri!.ToString());
        Assert.Equal("test-key", Assert.Single(brevo.Request.Headers.GetValues("api-key")));

        var payload = brevo.Payload;
        Assert.Equal("rap@test.local", payload.GetProperty("sender").GetProperty("email").GetString());
        Assert.Equal("khach@test.local", payload.GetProperty("to")[0].GetProperty("email").GetString());
        Assert.Equal(Otp.Subject, payload.GetProperty("subject").GetString());
        Assert.Equal(Otp.HtmlContent, payload.GetProperty("htmlContent").GetString());
        Assert.Equal(Otp.TextContent, payload.GetProperty("textContent").GetString());
    }

    [Fact]
    public async Task ARejectedEmailFailsWithBrevosReason()
    {
        var brevo = new FakeBrevo(
            HttpStatusCode.Unauthorized,
            """{"code":"unauthorized","message":"Key not found"}""");

        var error = await Assert.ThrowsAsync<HttpRequestException>(() => Sender(brevo).SendAsync(Otp));

        Assert.Equal(HttpStatusCode.Unauthorized, error.StatusCode);
        Assert.Contains("Key not found", error.Message);
    }

    [Fact]
    public async Task WithoutASenderNothingIsSent()
    {
        var brevo = new FakeBrevo(HttpStatusCode.Created);

        await Assert.ThrowsAsync<InvalidOperationException>(() => Sender(brevo, fromEmail: "").SendAsync(Otp));

        Assert.Null(brevo.Request);
    }
}
