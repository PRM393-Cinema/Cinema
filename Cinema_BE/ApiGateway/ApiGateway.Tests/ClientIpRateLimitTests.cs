using System.Net;
using ApiGateway.Helpers;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc.Testing;

namespace ApiGateway.Tests;

public sealed class ClientIpRateLimitTests
{
    private const string Header = "CF-Connecting-IP";

    [Fact]
    public async Task BehindAProxy_EachCustomerHasTheirOwnLimit()
    {
        await using var factory = new GatewayFactory(clientIpHeader: Header);
        using var client = factory.CreateClient();

        Assert.NotEqual(HttpStatusCode.TooManyRequests, await LoginFrom(client, "203.0.113.1"));
        Assert.NotEqual(HttpStatusCode.TooManyRequests, await LoginFrom(client, "203.0.113.1"));
        Assert.Equal(HttpStatusCode.TooManyRequests, await LoginFrom(client, "203.0.113.1"));

        // Another customer behind the same proxy is not blocked by the first one
        Assert.NotEqual(HttpStatusCode.TooManyRequests, await LoginFrom(client, "203.0.113.2"));
    }

    [Fact]
    public async Task WithoutAProxy_TheHeaderCannotBeUsedToDodgeTheLimit()
    {
        await using var factory = new GatewayFactory(clientIpHeader: "");
        using var client = factory.CreateClient();

        await LoginFrom(client, "203.0.113.1");
        await LoginFrom(client, "203.0.113.1");

        Assert.Equal(HttpStatusCode.TooManyRequests, await LoginFrom(client, "203.0.113.2"));
    }

    [Theory]
    [InlineData("203.0.113.7", "203.0.113.7")]
    [InlineData(" 2001:db8::1 ", "2001:db8::1")]
    [InlineData("not-an-ip", "10.0.0.1")]
    [InlineData("203.0.113.7, 10.0.0.2", "10.0.0.1")]
    [InlineData(null, "10.0.0.1")]
    public void Resolve_UsesTheProxyHeaderOnlyWhenItHoldsOneIp(string? value, string expected)
    {
        var context = new DefaultHttpContext();
        context.Connection.RemoteIpAddress = IPAddress.Parse("10.0.0.1");
        if (value is not null)
        {
            context.Request.Headers[Header] = value;
        }

        Assert.Equal(expected, ClientIp.Resolve(context, Header));
    }

    private static async Task<HttpStatusCode> LoginFrom(HttpClient client, string ip)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1/auth/login");
        request.Headers.Add(Header, ip);
        using var response = await client.SendAsync(request);
        return response.StatusCode;
    }

    private sealed class GatewayFactory(string clientIpHeader) : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Testing");
            builder.UseSetting("Jwt:SecretKey", "rate-limit-test-secret-key-with-32-chars");
            builder.UseSetting("Logging:LogLevel:Default", "Critical");
            builder.UseSetting("RateLimiting:AuthPermitLimit", "2");
            builder.UseSetting("RateLimiting:ClientIpHeader", clientIpHeader);
            // AuthService intentionally offline: only the limiter is under test
            builder.UseSetting("ReverseProxy:Clusters:auth-cluster:Destinations:auth-service:Address", "http://127.0.0.1:1/");
        }
    }
}
