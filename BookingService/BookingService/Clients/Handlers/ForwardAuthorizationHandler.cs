using System.Net.Http.Headers;

namespace BookingService.Clients.Handlers
{
    // MovieService tự kiểm tra JWT, nên khi gọi sang đó BookingService gửi kèm
    // token của chính người dùng trong request hiện tại (gọi thay mặt người dùng).
    public sealed class ForwardAuthorizationHandler : DelegatingHandler
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public ForwardAuthorizationHandler(IHttpContextAccessor httpContextAccessor)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            var authorization = _httpContextAccessor.HttpContext?
                .Request.Headers.Authorization.ToString();

            if (request.Headers.Authorization is null &&
                AuthenticationHeaderValue.TryParse(authorization, out var header))
            {
                request.Headers.Authorization = header;
            }

            return base.SendAsync(request, cancellationToken);
        }
    }
}
