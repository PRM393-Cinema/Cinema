using System.Net;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using ApiGateway.Middleware;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;

namespace ApiGateway.Tests;

public class AccountStatusMiddlewareTests
{
    [Fact]
    public async Task LockingAccount_BlocksNextRequestWithSameValidToken()
    {
        var locked = false;
        var checks = 0;
        var forwarded = 0;
        var clients = new TestClients(request =>
        {
            checks++;
            Assert.Equal("/api/v1/auth/me", request.RequestUri!.AbsolutePath);
            Assert.Equal("valid-token", request.Headers.Authorization?.Parameter);
            return locked
                ? new HttpResponseMessage(HttpStatusCode.Forbidden)
                {
                    Content = new StringContent(
                        "{\"errorCode\":\"ACCOUNT_LOCKED\",\"detail\":\"Account locked.\"}",
                        Encoding.UTF8, "application/problem+json")
                }
                : new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent("{\"roles\":[\"ROLE_CUSTOMER\"]}", Encoding.UTF8, "application/json")
                };
        });
        var middleware = new AccountStatusMiddleware(_ =>
        {
            forwarded++;
            return Task.CompletedTask;
        });

        await middleware.InvokeAsync(Context(), clients);
        Assert.Equal(1, forwarded);

        locked = true;
        var blocked = Context();
        await middleware.InvokeAsync(blocked, clients);
        Assert.Equal(2, checks);
        Assert.Equal(1, forwarded);
        Assert.Equal(403, blocked.Response.StatusCode);
        blocked.Response.Body.Position = 0;
        using var problem = await JsonDocument.ParseAsync(blocked.Response.Body);
        Assert.Equal("ACCOUNT_LOCKED", problem.RootElement.GetProperty("errorCode").GetString());

        locked = false;
        await middleware.InvokeAsync(Context(), clients);
        Assert.Equal(3, checks);
        Assert.Equal(2, forwarded);
    }

    [Theory]
    [InlineData("ROLE_CUSTOMER", "ROLE_STAFF")]
    [InlineData("ROLE_CUSTOMER", "ROLE_ADMIN")]
    [InlineData("ROLE_ADMIN", "ROLE_CUSTOMER")]
    public async Task RoleChange_BlocksOldTokenAndAcceptsNewRoles(string oldRole, string newRole)
    {
        var currentRole = oldRole;
        var forwarded = 0;
        var middleware = new AccountStatusMiddleware(_ =>
        {
            forwarded++;
            return Task.CompletedTask;
        });
        var clients = new TestClients(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(JsonSerializer.Serialize(new { roles = new[] { currentRole } }), Encoding.UTF8, "application/json")
        });

        await middleware.InvokeAsync(Context(role: oldRole), clients);
        Assert.Equal(1, forwarded);

        currentRole = newRole;
        var blocked = Context(role: oldRole);
        await middleware.InvokeAsync(blocked, clients);
        Assert.Equal(403, blocked.Response.StatusCode);
        Assert.Equal(1, forwarded);
        blocked.Response.Body.Position = 0;
        using var problem = await JsonDocument.ParseAsync(blocked.Response.Body);
        Assert.Equal("ROLE_CHANGED", problem.RootElement.GetProperty("errorCode").GetString());

        await middleware.InvokeAsync(Context(role: newRole), clients);
        Assert.Equal(2, forwarded);
    }

    [Theory]
    [InlineData("")]
    [InlineData("not-json")]
    [InlineData("{}")]
    [InlineData("{\"roles\":[]}")]
    [InlineData("{\"roles\":[null]}")]
    public async Task InvalidAccountResponse_DoesNotForward(string body)
    {
        var middleware = new AccountStatusMiddleware(_ => throw new InvalidOperationException("Unexpected forwarding."));
        var clients = new TestClients(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json")
        });
        var context = Context();
        await middleware.InvokeAsync(context, clients);
        Assert.Equal(503, context.Response.StatusCode);
    }

    [Theory]
    [InlineData(false, false)]
    [InlineData(true, true)]
    public async Task SignedOutOrAnonymousRequests_DoNotCheckAccount(bool signedIn, bool anonymous)
    {
        var forwarded = false;
        var middleware = new AccountStatusMiddleware(_ =>
        {
            forwarded = true;
            return Task.CompletedTask;
        });
        var clients = new TestClients(_ => throw new InvalidOperationException("Unexpected account check."));

        await middleware.InvokeAsync(Context(signedIn, anonymous), clients);
        Assert.True(forwarded);
    }

    [Theory]
    [InlineData(401, 401)]
    [InlineData(404, 401)]
    [InlineData(500, 503)]
    public async Task FailedAccountCheck_DoesNotForward(int upstreamStatus, int expectedStatus)
    {
        var middleware = new AccountStatusMiddleware(_ => throw new InvalidOperationException("Unexpected forwarding."));
        var clients = new TestClients(_ => new HttpResponseMessage((HttpStatusCode)upstreamStatus));
        var context = Context();

        await middleware.InvokeAsync(context, clients);
        Assert.Equal(expectedStatus, context.Response.StatusCode);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task UnreachableAuthService_BlocksRequestWith503(bool timeout)
    {
        var middleware = new AccountStatusMiddleware(_ => throw new InvalidOperationException("Unexpected forwarding."));
        var clients = new TestClients(_ => timeout
            ? throw new TaskCanceledException("Timeout")
            : throw new HttpRequestException("Offline"));
        var context = Context();

        await middleware.InvokeAsync(context, clients);
        Assert.Equal(503, context.Response.StatusCode);
    }

    private static DefaultHttpContext Context(bool signedIn = true, bool anonymous = false, string role = "ROLE_CUSTOMER")
    {
        var context = new DefaultHttpContext
        {
            RequestServices = new ServiceCollection().AddLogging().BuildServiceProvider()
        };
        context.Request.Path = "/api/v1/bookings";
        context.Request.Headers.Authorization = "Bearer valid-token";
        context.Response.Body = new MemoryStream();
        context.User = new ClaimsPrincipal(new ClaimsIdentity(
            [new Claim(ClaimTypes.NameIdentifier, "3"), new Claim(ClaimTypes.Role, role)], signedIn ? "Bearer" : null));
        context.SetEndpoint(new Endpoint(_ => Task.CompletedTask,
            anonymous
                ? new EndpointMetadataCollection(new AuthorizeAttribute(), new AllowAnonymousAttribute())
                : new EndpointMetadataCollection(new AuthorizeAttribute()), "Protected API"));
        return context;
    }

    private sealed class TestClients(Func<HttpRequestMessage, HttpResponseMessage> respond) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name)
        {
            Assert.Equal(AccountStatusMiddleware.HttpClientName, name);
            return new HttpClient(new TestHandler(respond)) { BaseAddress = new Uri("http://auth.test/") };
        }
    }

    private sealed class TestHandler(Func<HttpRequestMessage, HttpResponseMessage> respond) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            => Task.FromResult(respond(request));
    }
}
