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

            // Khách: controller điền user id từ token. Staff thu tiền tại quầy thì không cần (vé vãng lai)
            if (request.UserId is <= 0)
            {
                throw new BusinessException("User id must be greater than 0.");
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

        public static void ValidateCash(CashPaymentRequest request)
        {
            if (request == null)
            {
                throw new ArgumentNullException(nameof(request));
            }

            if (!request.BookingId.HasValue || request.BookingId <= 0)
            {
                throw new BusinessException("Booking id is required.");
            }

            if (!request.AmountReceived.HasValue || request.AmountReceived <= 0)
            {
                throw new BusinessException("Enter the cash the customer gave.");
            }
        }

        public static void ValidatePayment(PaymentRequest request)
        {
            if (request == null)
            {
                throw new ArgumentNullException(nameof(request));
            }

            if (!request.BookingId.HasValue || request.BookingId <= 0 ||
                request.UserId is <= 0)
            {
                throw new BusinessException(
                    "Booking id is required and user id must be greater than 0.");
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