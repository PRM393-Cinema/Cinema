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

            // Lỗi nghiệp vụ (4xx) chỉ ghi cảnh báo; lỗi hệ thống (5xx) ghi kèm stack trace
            if (statusCode >= StatusCodes.Status500InternalServerError)
            {
                _logger.LogError(exception, "Request {Method} {Path} failed: {Message}",
                    httpContext.Request.Method, httpContext.Request.Path, exception.Message);
            }
            else
            {
                _logger.LogWarning("Request {Method} {Path} returned {StatusCode}: {Message}",
                    httpContext.Request.Method, httpContext.Request.Path, statusCode, exception.Message);
            }

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
