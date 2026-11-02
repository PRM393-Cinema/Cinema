using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using MovieService.Chat;

namespace MovieService.Controllers;

[ApiController, Route("api/v1/chat")]
public sealed class ChatController(CinemaChatService chat) : ControllerBase
{
    [HttpPost, AllowAnonymous, RequestSizeLimit(65536), EnableRateLimiting("chat")]
    public async Task<ActionResult<ChatReply>> Reply(ChatRequest request, CancellationToken cancellationToken)
        => await Respond(request, cancellationToken, authenticated: false);

    [HttpPost("account"), Authorize, RequestSizeLimit(65536), EnableRateLimiting("chat")]
    public async Task<ActionResult<ChatReply>> AccountReply(ChatRequest request, CancellationToken cancellationToken)
        => await Respond(request, cancellationToken, authenticated: true);

    private async Task<ActionResult<ChatReply>> Respond(ChatRequest request, CancellationToken cancellationToken, bool authenticated)
    {
        if (!chat.IsConfigured)
            return Problem(statusCode: 503, detail: "Cinema AI is not configured yet. Please try again later.");
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(120));
        try
        {
            var token = authenticated && User.Identity?.IsAuthenticated == true && Request.Headers.Authorization.ToString().StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
                ? Request.Headers.Authorization.ToString()[7..] : null;
            return Ok(await chat.ReplyAsync(request, timeout.Token, token));
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return Problem(statusCode: 504, detail: "Cinema AI took too long. Please try again.");
        }
        catch (System.Exception error) when (error is HttpRequestException or JsonException or InvalidDataException or InvalidOperationException or KeyNotFoundException)
        {
            // Provider errors may contain account details; return a fixed public message.
            return Problem(statusCode: 502, detail: "Cinema AI is temporarily unavailable. Please try again later.");
        }
    }
}
