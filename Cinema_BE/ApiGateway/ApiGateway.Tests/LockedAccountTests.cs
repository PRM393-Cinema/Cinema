using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using ApiGateway.Middleware;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;

namespace ApiGateway.Tests;

public class LockedAccountTests
{
    private const string Secret = "test-only-jwt-secret-key-with-at-least-32-chars";

    [Theory]
    [InlineData("/api/v1/auth/me")]
    [InlineData("/api/v1/auth/users")]
    [InlineData("/api/v1/bookings/1")]
    public async Task ProtectedRoutes_RejectLockedAccountBeforeForwarding(string path)
    {
        await using var factory = new GatewayFactory();
        using var client = factory.CreateClient();
        var token = new JwtSecurityToken("CinemaAuthService", "CinemaClients",
            [new Claim(ClaimTypes.NameIdentifier, "3"), new Claim(ClaimTypes.Role, "ROLE_ADMIN")],
            expires: DateTime.UtcNow.AddMinutes(5),
            signingCredentials: new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(Secret)), SecurityAlgorithms.HmacSha256));
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", new JwtSecurityTokenHandler().WriteToken(token));

        using var response = await client.GetAsync(path);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        using var problem = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync());
        Assert.Equal("ACCOUNT_LOCKED", problem.RootElement.GetProperty("errorCode").GetString());
    }

    [Theory]
    [InlineData("ROLE_STAFF")]
    [InlineData("ROLE_ADMIN")]
    public async Task ChangedCustomerRole_RejectsExistingToken(string currentRole)
    {
        await using var factory = new GatewayFactory(currentRole);
        using var client = factory.CreateClient();
        var token = new JwtSecurityToken("CinemaAuthService", "CinemaClients",
            [new Claim(ClaimTypes.NameIdentifier, "3"), new Claim(ClaimTypes.Role, "ROLE_CUSTOMER")],
            expires: DateTime.UtcNow.AddMinutes(5),
            signingCredentials: new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(Secret)), SecurityAlgorithms.HmacSha256));
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", new JwtSecurityTokenHandler().WriteToken(token));

        using var response = await client.GetAsync("/api/v1/bookings/1");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        using var problem = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync());
        Assert.Equal("ROLE_CHANGED", problem.RootElement.GetProperty("errorCode").GetString());
    }

    private sealed class GatewayFactory(string? currentRole = null) : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Testing");
            builder.UseSetting("Jwt:SecretKey", Secret);
            builder.UseSetting("Logging:LogLevel:Default", "Error");
            foreach (var cluster in new[] { "auth-cluster", "movie-cluster", "booking-cluster" })
            {
                builder.UseSetting($"ReverseProxy:Clusters:{cluster}:HealthCheck:Active:Enabled", "false");
            }
            builder.ConfigureTestServices(services => services
                .AddHttpClient(AccountStatusMiddleware.HttpClientName)
                .ConfigurePrimaryHttpMessageHandler(() => new LockedAuthHandler(currentRole)));
        }
    }

    private sealed class LockedAuthHandler(string? currentRole = null) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            => Task.FromResult(new HttpResponseMessage(currentRole is null ? HttpStatusCode.Forbidden : HttpStatusCode.OK)
            {
                Content = new StringContent(currentRole is null
                    ? "{\"errorCode\":\"ACCOUNT_LOCKED\",\"detail\":\"Account locked.\"}"
                    : JsonSerializer.Serialize(new { roles = new[] { currentRole } }),
                    Encoding.UTF8, "application/problem+json")
            });
    }
}
