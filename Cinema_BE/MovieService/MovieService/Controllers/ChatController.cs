using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using MovieService.Chat;

namespace MovieService.Controllers;

[ApiController, Route("api/v1/chat"), AllowAnonymous]
public sealed class ChatController(CinemaChatService chat) : ControllerBase
{
    [HttpPost, RequestSizeLimit(65536), EnableRateLimiting("chat")]
    public async Task<ActionResult<ChatReply>> Reply(ChatRequest request, CancellationToken cancellationToken)
    {
        if (!chat.IsConfigured)
            return Problem(statusCode: 503, detail: "Cinema AI is not configured yet. Please try again later.");
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(60));
        try
        {
            return Ok(await chat.ReplyAsync(request, timeout.Token));
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return Problem(statusCode: 504, detail: "Cinema AI took too long. Please try again.");
        }
        catch (System.Exception error) when (error is HttpRequestException or JsonException or InvalidDataException)
        {
            // Provider errors may contain account details; return a fixed public message.
            return Problem(statusCode: 502, detail: "Cinema AI is temporarily unavailable. Please try again later.");
        }
    }
}
