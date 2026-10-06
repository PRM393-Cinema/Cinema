using BookingService.DTOs.Requests;
using BookingService.Exceptions;

namespace BookingService.Validators
{
    public static class PaymentValidator
    {
        public static void ValidatePayOsCreate(PayOsCreateRequest request)
        {
            if (request == null)
            {
                throw new ArgumentNullException(nameof(request));
            }

            if (!request.BookingId.HasValue || request.BookingId <= 0)
            {
                throw new BusinessException("Booking id is required.");
            }

            if (!request.UserId.HasValue || request.UserId <= 0)
            {
                throw new BusinessException("User id is required.");
            }

            if (!request.Amount.HasValue || request.Amount <= 0)
            {
                throw new BusinessException("Amount must be greater than 0.");
            }

            if (string.IsNullOrWhiteSpace(request.ReturnUrl) ||
                string.IsNullOrWhiteSpace(request.CancelUrl))
            {
                throw new BusinessException(
                    "Return URL and cancel URL are required.");
            }
        }

        public static void ValidatePayment(PaymentRequest request)
        {
            if (request == null)
            {
                throw new ArgumentNullException(nameof(request));
            }

            if (!request.BookingId.HasValue || request.BookingId <= 0 ||
                !request.UserId.HasValue || request.UserId <= 0)
            {
                throw new BusinessException(
                    "Booking id and user id are required.");
            }

            if (!request.Amount.HasValue || request.Amount <= 0)
            {
                throw new BusinessException("Amount must be greater than 0.");
            }

            if (string.IsNullOrWhiteSpace(request.Method))
            {
                throw new BusinessException("Payment method is required.");
            }
        }
    }
}