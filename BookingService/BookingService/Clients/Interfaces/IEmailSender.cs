using BookingService.DTOs;

namespace BookingService.Clients.Interfaces
{
    public interface IEmailSender
    {
        Task SendAsync(
            EmailMessage email,
            CancellationToken cancellationToken = default);
    }
}