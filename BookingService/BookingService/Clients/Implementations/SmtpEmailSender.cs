using System.Net;
using System.Net.Mail;
using BookingService.Configuration;
using BookingService.DTOs;
using BookingService.Exceptions;
using BookingService.Clients.Interfaces;
using Microsoft.Extensions.Options;

namespace BookingService.Clients.Implementations
{
    public sealed class SmtpEmailSender : IEmailSender
    {
        private readonly SmtpOptions _options;

        public SmtpEmailSender(IOptions<SmtpOptions> options)
        {
            _options = options.Value;
        }

        public async Task SendAsync(
            EmailMessage email,
            CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(_options.Host) ||
                string.IsNullOrWhiteSpace(_options.FromEmail))
            {
                throw new ExternalServiceException(
                    "SMTP email settings are not configured.");
            }

            using var message = new MailMessage
            {
                From = new MailAddress(_options.FromEmail, _options.FromName),
                Subject = email.Subject,
                Body = email.Content,
                IsBodyHtml = true
            };

            message.To.Add(new MailAddress(email.RecipientEmail));

            using var client = new SmtpClient(_options.Host, _options.Port)
            {
                EnableSsl = _options.EnableSsl,
                Timeout = _options.TimeoutSeconds * 1000,
                DeliveryMethod = SmtpDeliveryMethod.Network,
                UseDefaultCredentials = false,
                Credentials = new NetworkCredential(
                    _options.Username,
                    _options.Password)
            };

            await client.SendMailAsync(message).WaitAsync(cancellationToken);
        }
    }
}