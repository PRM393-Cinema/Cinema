using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace ApiGateway.Health
{
    // Gọi /health của một service phía sau (Auth/Movie/Booking) để báo service đó còn phục vụ được không
    public sealed class DownstreamHealthCheck : IHealthCheck
    {
        public const string HttpClientName = "downstream-health";

        private readonly IHttpClientFactory _httpClientFactory;
        private readonly Uri _healthUri;

        public DownstreamHealthCheck(IHttpClientFactory httpClientFactory, Uri healthUri)
        {
            _httpClientFactory = httpClientFactory;
            _healthUri = healthUri;
        }

        public async Task<HealthCheckResult> CheckHealthAsync(
            HealthCheckContext context,
            CancellationToken cancellationToken = default)
        {
            try
            {
                var client = _httpClientFactory.CreateClient(HttpClientName);
                using var response = await client.GetAsync(_healthUri, cancellationToken);

                return response.IsSuccessStatusCode
                    ? HealthCheckResult.Healthy()
                    : HealthCheckResult.Unhealthy($"Service trả về {(int)response.StatusCode} (xem /health của service để biết database nào lỗi).");
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                return HealthCheckResult.Unhealthy("Không gọi được service (service chưa chạy hoặc sai địa chỉ).", ex);
            }
        }
    }
}
