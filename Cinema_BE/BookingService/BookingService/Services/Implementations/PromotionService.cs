using BookingService.Clients.Interfaces;
using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Exceptions;
using BookingService.Helpers;
using BookingService.Mapping;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using BookingService.Services.Interfaces;

namespace BookingService.Services.Implementations
{
    public class PromotionService : IPromotionService
    {
        private readonly IPromotionRepository _repository;
        private readonly IShowtimeClient _showtimeClient;

        public PromotionService(IPromotionRepository repository, IShowtimeClient showtimeClient)
        {
            _repository = repository;
            _showtimeClient = showtimeClient;
        }

        public async Task<List<PromotionResponse>> GetPromotionsAsync(bool all)
        {
            var now = DateTime.Now;
            var promotions = all
                ? await _repository.GetAllAsync()
                : (await _repository.GetActiveAutomaticAsync())
                    .Where(promotion => promotion.EndsAt is null || promotion.EndsAt >= now)
                    .ToList();

            return promotions.Select(promotion => promotion.ToResponse()).ToList();
        }

        public async Task<PromotionResponse> CreateAsync(PromotionRequest request)
        {
            var promotion = new Promotion { CreatedAt = DateTime.Now, Active = true };
            await ApplyAsync(promotion, request);
            await _repository.AddAsync(promotion);
            await _repository.SaveChangesAsync();
            return promotion.ToResponse();
        }

        public async Task<PromotionResponse> UpdateAsync(long id, PromotionRequest request)
        {
            var promotion = await _repository.GetByIdAsync(id)
                ?? throw new NotFoundException($"Promotion {id} was not found.");
            await ApplyAsync(promotion, request);
            await _repository.SaveChangesAsync();
            return promotion.ToResponse();
        }

        public async Task<PromotionQuoteResponse> QuoteAsync(PromotionQuoteRequest request)
        {
            var showtime = await _showtimeClient.GetShowtimeAsync(request.ShowtimeId!.Value);
            var (promotion, discount) = await ResolveAsync(
                request.Code,
                request.TicketAmount,
                request.Tickets,
                showtime.StartTime);

            return new PromotionQuoteResponse
            {
                PromotionId = promotion?.Id,
                Code = promotion?.Code,
                Name = promotion?.Name,
                Description = promotion?.Description,
                Discount = discount
            };
        }

        public async Task<(Promotion? Promotion, decimal Discount)> ResolveAsync(
            string? code,
            decimal ticketAmount,
            int tickets,
            DateTime showStart)
        {
            var now = DateTime.Now;

            if (!string.IsNullOrWhiteSpace(code))
            {
                var normalized = code.Trim().ToUpperInvariant();
                var promotion = await _repository.GetByCodeAsync(normalized)
                    ?? throw new BusinessException($"Promo code {normalized} is not valid.");

                var why = PromotionRules.WhyNot(promotion, tickets, showStart, now);
                if (why != null)
                {
                    throw new BusinessException(why);
                }

                var discount = PromotionRules.Discount(promotion, ticketAmount);
                if (discount <= 0)
                {
                    throw new BusinessException($"Promo code {normalized} gives no discount on these tickets.");
                }

                return (promotion, discount);
            }

            // Không nhập mã: khuyến mãi tự áp dụng giảm nhiều nhất
            return (await _repository.GetActiveAutomaticAsync())
                .Where(promotion => PromotionRules.WhyNot(promotion, tickets, showStart, now) == null)
                .Select(promotion => (Promotion: (Promotion?)promotion, Discount: PromotionRules.Discount(promotion, ticketAmount)))
                .Where(candidate => candidate.Discount > 0)
                .OrderByDescending(candidate => candidate.Discount)
                .FirstOrDefault();
        }

        private async Task ApplyAsync(Promotion promotion, PromotionRequest request)
        {
            var type = request.DiscountType!.Trim().ToUpperInvariant();
            if (type == "PERCENT" && request.DiscountValue > 90)
            {
                throw new BusinessException("A percentage discount must be at most 90%.");
            }

            if (request.StartsAt.HasValue && request.EndsAt.HasValue && request.EndsAt <= request.StartsAt)
            {
                throw new BusinessException("The end must be after the start.");
            }

            var days = (request.DaysOfWeek ?? new List<int>()).Distinct().OrderBy(day => day).ToList();
            if (days.Any(day => day is < 1 or > 7))
            {
                throw new BusinessException("Days of the week must be 1 (Monday) to 7 (Sunday).");
            }

            var code = string.IsNullOrWhiteSpace(request.Code) ? null : request.Code.Trim().ToUpperInvariant();
            if (code != null && await _repository.CodeExistsAsync(code, promotion.Id == 0 ? null : promotion.Id))
            {
                throw new ConflictException($"Promo code {code} is already used by another promotion.");
            }

            promotion.Code = code;
            promotion.Name = request.Name!.Trim();
            promotion.Description = string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim();
            promotion.DiscountType = type;
            promotion.DiscountValue = request.DiscountValue!.Value;
            promotion.MaxDiscount = type == "PERCENT" ? request.MaxDiscount : null;
            promotion.MinTickets = request.MinTickets ?? 1;
            promotion.DaysOfWeek = days.Count == 0 ? null : string.Join(",", days);
            promotion.StartsAt = request.StartsAt;
            promotion.EndsAt = request.EndsAt;
            promotion.UsageLimit = request.UsageLimit;
            promotion.Active = request.Active ?? promotion.Active;
        }
    }
}
