using System.Net;
using System.Text.Json;
using BookingService.Clients.Implementations;
using BookingService.Configuration;
using BookingService.Exceptions;
using BookingService.Messaging;
using BookingService.Messaging.Handlers;
using Microsoft.Extensions.Options;

namespace BookingService.Tests.Unit;

public class BrevoEmailSenderTests
{
    private static readonly BookingEventData Booking = new()
    {
        BookingId = 1,
        BookingCode = "BK-1",
        UserId = 3,
        CustomerEmail = "khach@test.local",
        MovieTitle = "Phim Hay",
        ShowTime = new DateTime(2026, 12, 20, 19, 30, 0),
        Seats = new List<string> { "A1", "A2" },
        TotalAmount = 180_000,
        Status = "CONFIRMED"
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

        await Sender(brevo).SendAsync(EmailTemplates.BookingExpired(Booking, "khach@test.local"));

        Assert.Equal(HttpMethod.Post, brevo.Request!.Method);
        Assert.Equal("https://api.brevo.com/v3/smtp/email", brevo.Request.RequestUri!.ToString());
        Assert.Equal("test-key", Assert.Single(brevo.Request.Headers.GetValues("api-key")));

        var payload = brevo.Payload;
        Assert.Equal("rap@test.local", payload.GetProperty("sender").GetProperty("email").GetString());
        Assert.Equal("Mobile Cinema", payload.GetProperty("sender").GetProperty("name").GetString());
        Assert.Equal("khach@test.local", payload.GetProperty("to")[0].GetProperty("email").GetString());
        Assert.Contains("BK-1", payload.GetProperty("subject").GetString());
        Assert.Contains("BK-1", payload.GetProperty("htmlContent").GetString());
        // No images: no attachment field at all
        Assert.False(payload.TryGetProperty("attachment", out _));
    }

    [Fact]
    public async Task TheTicketQrIsAttachedAsAFile()
    {
        var brevo = new FakeBrevo(HttpStatusCode.Created);
        var email = EmailTemplates.BookingConfirmed(Booking, "khach@test.local");

        await Sender(brevo).SendAsync(email);

        // Brevo cannot embed cid: images, so the <img> becomes a pointer to the attachment
        var html = brevo.Payload.GetProperty("htmlContent").GetString()!;
        Assert.DoesNotContain("cid:", html);
        Assert.Contains("ma-qr-BK-1.png", html);

        var attachment = Assert.Single(brevo.Payload.GetProperty("attachment").EnumerateArray());
        Assert.Equal("ma-qr-BK-1.png", attachment.GetProperty("name").GetString());
        Assert.Equal(
            email.InlineImages[0].Content,
            Convert.FromBase64String(attachment.GetProperty("content").GetString()!));
    }

    [Fact]
    public async Task ARejectedEmailFailsWithBrevosReason()
    {
        var brevo = new FakeBrevo(
            HttpStatusCode.Unauthorized,
            """{"code":"unauthorized","message":"Key not found"}""");

        var error = await Assert.ThrowsAsync<ExternalServiceException>(
            () => Sender(brevo).SendAsync(EmailTemplates.BookingExpired(Booking, "khach@test.local")));

        Assert.Contains("401", error.Message);
        Assert.Contains("Key not found", error.Message);
    }

    [Fact]
    public async Task WithoutASenderNothingIsSent()
    {
        var brevo = new FakeBrevo(HttpStatusCode.Created);

        await Assert.ThrowsAsync<ExternalServiceException>(
            () => Sender(brevo, fromEmail: "").SendAsync(EmailTemplates.BookingExpired(Booking, "khach@test.local")));

        Assert.Null(brevo.Request);
    }
}
