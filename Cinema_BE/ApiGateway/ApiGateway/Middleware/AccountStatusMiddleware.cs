using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using ApiGateway.Helpers;
using Microsoft.AspNetCore.Authorization;

namespace ApiGateway.Middleware;

public class AccountStatusMiddleware(RequestDelegate next)
{
    public const string HttpClientName = "account-status";

    public async Task InvokeAsync(HttpContext context, IHttpClientFactory clients)
    {
        var endpoint = context.GetEndpoint();
        if (context.User.Identity?.IsAuthenticated != true ||
            endpoint?.Metadata.GetMetadata<IAllowAnonymous>() is not null ||
            endpoint?.Metadata.GetMetadata<IAuthorizeData>() is null)
        {
            await next(context);
            return;
        }

        using var request = new HttpRequestMessage(HttpMethod.Get, "api/v1/auth/me");
        request.Headers.TryAddWithoutValidation("Authorization", context.Request.Headers.Authorization.ToString());
        request.Headers.TryAddWithoutValidation(CorrelationIdMiddleware.HeaderName,
            context.Request.Headers[CorrelationIdMiddleware.HeaderName].ToString());

        HttpResponseMessage response;
        try
        {
            response = await clients.CreateClient(HttpClientName).SendAsync(request, context.RequestAborted);
        }
        catch (HttpRequestException)
        {
            await UnavailableAsync(context);
            return;
        }
        catch (OperationCanceledException) when (!context.RequestAborted.IsCancellationRequested)
        {
            await UnavailableAsync(context);
            return;
        }

        using (response)
        {
            if (response.IsSuccessStatusCode)
            {
                AccountStatus? account;
                try
                {
                    account = await response.Content.ReadFromJsonAsync<AccountStatus>(context.RequestAborted);
                }
                catch (JsonException)
                {
                    await UnavailableAsync(context);
                    return;
                }

                if (account?.Roles is null || account.Roles.Length == 0 || account.Roles.Any(string.IsNullOrWhiteSpace))
                {
                    await UnavailableAsync(context);
                    return;
                }

                var tokenRoles = context.User.FindAll(ClaimTypes.Role)
                    .Select(claim => claim.Value).ToHashSet(StringComparer.Ordinal);
                if (!tokenRoles.SetEquals(account.Roles))
                {
                    await GatewayProblem.WriteAsync(context, StatusCodes.Status403Forbidden, "Forbidden",
                        "Vai trò tài khoản đã thay đổi. Vui lòng đăng nhập lại.", "ROLE_CHANGED");
                    return;
                }

                await next(context);
                return;
            }

            if (response.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
            {
                context.Response.StatusCode = (int)response.StatusCode;
                context.Response.ContentType = response.Content.Headers.ContentType?.ToString()
                    ?? "application/problem+json";
                await response.Content.CopyToAsync(context.Response.Body, context.RequestAborted);
                return;
            }

            if (response.StatusCode == HttpStatusCode.NotFound)
            {
                await GatewayProblem.WriteAsync(context, StatusCodes.Status401Unauthorized, "Unauthorized",
                    "Tài khoản không còn tồn tại. Vui lòng đăng nhập lại.");
                return;
            }

            await UnavailableAsync(context);
        }
    }

    private static Task UnavailableAsync(HttpContext context) => GatewayProblem.WriteAsync(
        context, StatusCodes.Status503ServiceUnavailable, "Service Unavailable",
        "Không thể kiểm tra trạng thái tài khoản. Vui lòng thử lại sau.");

    private sealed record AccountStatus(string[] Roles);
}
