using System.Net.Mail;
using BookingService.DTOs;
using BookingService.DTOs.Requests;
using BookingService.Exceptions;

namespace BookingService.Validators
{
    public static class NotificationValidator
    {
        public static void Validate(NotificationRequest request)
        {
            if (request == null)
            {
                throw new ArgumentNullException(nameof(request));
            }

            if (!request.UserId.HasValue || request.UserId <= 0)
            {
                throw new BusinessException("User id is required.");
            }

            if (string.IsNullOrWhiteSpace(request.RecipientEmail) ||
                !IsEmail(request.RecipientEmail))
            {
                throw new BusinessException("Recipient email is invalid.");
            }

            if (string.IsNullOrWhiteSpace(request.Subject) ||
                string.IsNullOrWhiteSpace(request.Type) ||
                string.IsNullOrWhiteSpace(request.Content))
            {
                throw new BusinessException(
                    "Notification type, subject and content are required.");
            }
        }

        public static void ValidateEmail(EmailMessage email)
        {
            if (email == null ||
                string.IsNullOrWhiteSpace(email.RecipientEmail) ||
                !IsEmail(email.RecipientEmail) ||
                string.IsNullOrWhiteSpace(email.Subject) ||
                string.IsNullOrWhiteSpace(email.Content))
            {
                throw new BusinessException("Email message is invalid.");
            }
        }

        private static bool IsEmail(string value)
        {
            try
            {
                _ = new MailAddress(value);
                return true;
            }
            catch (FormatException)
            {
                return false;
            }
        }
    }
}