using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace ApiGateway.Tests;

public sealed class ChatRateLimitTests
{
    [Fact]
    public async Task GuestChat_IsForwardedWithoutLogin_AndRateLimitedAfterTenRequests()
    {
        await using var factory = new ChatGatewayFactory();
        using var client = factory.CreateClient();
        for (var i = 0; i < 10; i++)
        {
            using var response = await client.PostAsJsonAsync("/api/v1/chat", new { messages = Array.Empty<object>() });
            Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode); // Destination intentionally offline.
        }
        using var limited = await client.PostAsJsonAsync("/api/v1/chat", new { messages = Array.Empty<object>() });
        Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
        Assert.NotNull(limited.Headers.RetryAfter);
    }

    private sealed class ChatGatewayFactory : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Testing");
            builder.UseSetting("Jwt:SecretKey", "chat-test-secret-key-with-at-least-32-chars");
            builder.UseSetting("Logging:LogLevel:Default", "Critical");
            builder.UseSetting("ReverseProxy:Clusters:movie-cluster:Destinations:movie-service:Address", "http://127.0.0.1:1/");
        }
    }
}
