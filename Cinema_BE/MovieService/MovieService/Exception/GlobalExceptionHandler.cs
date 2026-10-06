using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace MovieService.Exception
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
                ConflictException => (StatusCodes.Status409Conflict, "Conflict"),
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

            httpContext.Response.StatusCode = statusCode;
            await httpContext.Response.WriteAsJsonAsync(problemDetails, cancellationToken);

            return true; // Báo hiệu đã xử lý xong exception
        }
    }
}
