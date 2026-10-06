using ApiGateway.Middleware;
using Microsoft.AspNetCore.Mvc;

namespace ApiGateway.Helpers
{
    // Trả lỗi của gateway theo cùng định dạng ProblemDetails như các service phía sau
    public static class GatewayProblem
    {
        public static Task WriteAsync(HttpContext context, int statusCode, string title, string detail)
        {
            var problem = new ProblemDetails
            {
                Status = statusCode,
                Title = title,
                Detail = detail,
                Instance = context.Request.Path
            };

            if (context.Items.TryGetValue(CorrelationIdMiddleware.ItemKey, out var correlationId))
            {
                problem.Extensions["correlationId"] = correlationId;
            }

            context.Response.StatusCode = statusCode;

            return context.Response.WriteAsJsonAsync(problem, options: null, contentType: "application/problem+json");
        }
    }
}
