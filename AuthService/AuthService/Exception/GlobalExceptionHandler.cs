using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace AuthService.Exception
{
    public class GlobalExceptionHandler : IExceptionHandler
    {
        private readonly ILogger<GlobalExceptionHandler> _logger;

        public GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger)
        {
            _logger = logger;
        }

        public async ValueTask<bool> TryHandleAsync(
            HttpContext httpContext,
            System.Exception exception,
            CancellationToken cancellationToken)
        {
            _logger.LogError(exception, "An unhandled exception occurred: {Message}", exception.Message);

            var (statusCode, title) = exception switch
            {
                NotFoundException => (StatusCodes.Status404NotFound, "Resource Not Found"),
                UnauthorizedException => (StatusCodes.Status401Unauthorized, "Unauthorized"),
                ForbiddenException => (StatusCodes.Status403Forbidden, "Forbidden"),
                TooManyRequestsException => (StatusCodes.Status429TooManyRequests, "Too Many Requests"),
                ServiceUnavailableException => (StatusCodes.Status503ServiceUnavailable, "Service Unavailable"),
                BusinessException => (StatusCodes.Status400BadRequest, "Bad Request"),
                _ => (StatusCodes.Status500InternalServerError, "Server Error")
            };

            var problemDetails = new ProblemDetails
            {
                Status = statusCode,
                Title = title,
                Detail = exception.Message,
                Instance = httpContext.Request.Path
            };

            if (exception is ForbiddenException { ErrorCode: not null } forbidden)
            {
                problemDetails.Extensions["errorCode"] = forbidden.ErrorCode;
            }

            if (exception is TooManyRequestsException tooManyRequests)
            {
                httpContext.Response.Headers.RetryAfter = tooManyRequests.RetryAfterSeconds.ToString();
            }

            httpContext.Response.StatusCode = statusCode;
            await httpContext.Response.WriteAsJsonAsync(problemDetails, cancellationToken);

            return true; // Báo hiệu đã xử lý xong exception
        }
    }
}
