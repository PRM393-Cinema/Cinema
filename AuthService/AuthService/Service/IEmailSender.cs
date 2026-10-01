using AuthService.DTOs;

namespace AuthService.Service
{
    public interface IEmailSender
    {
        Task SendAsync(EmailMessage email, CancellationToken cancellationToken = default);
    }
}
