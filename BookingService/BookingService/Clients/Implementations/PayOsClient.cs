using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Serialization;
using BookingService.Configuration;
using BookingService.Clients.Interfaces;
using BookingService.Exceptions;
using Microsoft.Extensions.Options;

namespace BookingService.Clients.Implementations
{
    public sealed class PayOsClient : IPayOsClient
    {
        private readonly HttpClient _httpClient;
        private readonly PayOsOptions _options;

        public PayOsClient(
            HttpClient httpClient,
            IOptions<PayOsOptions> options)
        {
            _httpClient = httpClient;
            _options = options.Value;
        }

        public async Task<PayOsPaymentLink> CreatePaymentLinkAsync(
            long orderCode,
            decimal amount,
            string description,
            string returnUrl,
            string cancelUrl,
            CancellationToken cancellationToken = default)
        {
            EnsureConfigured();

            var amountValue = decimal.ToInt64(decimal.Truncate(amount));
            var payload = new PayOsCreatePaymentPayload
            {
                OrderCode = orderCode,
                Amount = amountValue,
                Description = description,
                ReturnUrl = returnUrl,
                CancelUrl = cancelUrl,
                Signature = CreateSignature(
                    $"amount={amountValue}&cancelUrl={cancelUrl}&description={description}&orderCode={orderCode}&returnUrl={returnUrl}")
            };

            using var request = new HttpRequestMessage(
                HttpMethod.Post,
                "v2/payment-requests")
            {
                Content = JsonContent.Create(payload)
            };

            AddHeaders(request);

            var response = await _httpClient.SendAsync(
                request,
                cancellationToken);

            var result = await ReadResponseAsync<PayOsCreateResponse>(
                response,
                cancellationToken);

            if (result.Data == null)
            {
                throw new ExternalServiceException(
                    "PayOS did not return payment link data.");
            }

            return new PayOsPaymentLink
            {
                OrderCode = result.Data.OrderCode,
                CheckoutUrl = result.Data.CheckoutUrl,
                PaymentLinkId = result.Data.PaymentLinkId
            };
        }

        public async Task<PayOsPaymentStatus> GetPaymentStatusAsync(
            long orderCode,
            CancellationToken cancellationToken = default)
        {
            EnsureConfigured();

            using var request = new HttpRequestMessage(
                HttpMethod.Get,
                $"v2/payment-requests/{orderCode}");

            AddHeaders(request);

            var response = await _httpClient.SendAsync(
                request,
                cancellationToken);

            var result = await ReadResponseAsync<PayOsStatusResponse>(
                response,
                cancellationToken);

            if (result.Data == null)
            {
                throw new ExternalServiceException(
                    "PayOS did not return payment status data.");
            }

            return new PayOsPaymentStatus
            {
                OrderCode = result.Data.OrderCode,
                Status = result.Data.Status ?? string.Empty,
                PaymentLinkId = result.Data.PaymentLinkId,
                CheckoutUrl = result.Data.CheckoutUrl
            };
        }

        private async Task<T> ReadResponseAsync<T>(
            HttpResponseMessage response,
            CancellationToken cancellationToken)
            where T : PayOsResponse
        {
            var result = await response.Content.ReadFromJsonAsync<T>(
                cancellationToken: cancellationToken);

            if (!response.IsSuccessStatusCode ||
                result == null ||
                !string.Equals(result.Code, "00", StringComparison.Ordinal))
            {
                throw new ExternalServiceException(
                    result?.Description ??
                    $"PayOS request failed with status {(int)response.StatusCode}.");
            }

            return result;
        }

        private void AddHeaders(HttpRequestMessage request)
        {
            request.Headers.Add("x-client-id", _options.ClientId);
            request.Headers.Add("x-api-key", _options.ApiKey);
        }

        private string CreateSignature(string data)
        {
            using var hmac = new HMACSHA256(
                Encoding.UTF8.GetBytes(_options.ChecksumKey));

            return Convert.ToHexString(
                    hmac.ComputeHash(Encoding.UTF8.GetBytes(data)))
                .ToLowerInvariant();
        }

        private void EnsureConfigured()
        {
            if (string.IsNullOrWhiteSpace(_options.ClientId) ||
                string.IsNullOrWhiteSpace(_options.ApiKey) ||
                string.IsNullOrWhiteSpace(_options.ChecksumKey))
            {
                throw new ExternalServiceException(
                    "PayOS credentials are not configured.");
            }
        }

        private abstract class PayOsResponse
        {
            [JsonPropertyName("code")]
            public string? Code { get; set; }

            [JsonPropertyName("desc")]
            public string? Description { get; set; }
        }

        private sealed class PayOsCreatePaymentPayload
        {
            [JsonPropertyName("orderCode")]
            public long OrderCode { get; init; }

            [JsonPropertyName("amount")]
            public long Amount { get; init; }

            [JsonPropertyName("description")]
            public string Description { get; init; } = string.Empty;

            [JsonPropertyName("returnUrl")]
            public string ReturnUrl { get; init; } = string.Empty;

            [JsonPropertyName("cancelUrl")]
            public string CancelUrl { get; init; } = string.Empty;

            [JsonPropertyName("signature")]
            public string Signature { get; init; } = string.Empty;
        }

        private sealed class PayOsCreateResponse : PayOsResponse
        {
            [JsonPropertyName("data")]
            public PayOsCreateData? Data { get; set; }
        }

        private sealed class PayOsStatusResponse : PayOsResponse
        {
            [JsonPropertyName("data")]
            public PayOsStatusData? Data { get; set; }
        }

        private sealed class PayOsCreateData
        {
            [JsonPropertyName("orderCode")]
            public long OrderCode { get; set; }

            [JsonPropertyName("checkoutUrl")]
            public string? CheckoutUrl { get; set; }

            [JsonPropertyName("id")]
            public string? PaymentLinkId { get; set; }
        }

        private sealed class PayOsStatusData
        {
            [JsonPropertyName("orderCode")]
            public long OrderCode { get; set; }

            [JsonPropertyName("status")]
            public string? Status { get; set; }

            [JsonPropertyName("id")]
            public string? PaymentLinkId { get; set; }

            [JsonPropertyName("checkoutUrl")]
            public string? CheckoutUrl { get; set; }
        }
    }
}