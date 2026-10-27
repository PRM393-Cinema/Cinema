using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Models;

namespace BookingService.Services.Interfaces
{
    public interface IPromotionService
    {
        // all = false: khuyến mãi tự áp dụng đang chạy (cho khách xem); true: tất cả (Admin)
        Task<List<PromotionResponse>> GetPromotionsAsync(bool all);

        Task<PromotionResponse> CreateAsync(PromotionRequest request);

        Task<PromotionResponse> UpdateAsync(long id, PromotionRequest request);

        Task<PromotionQuoteResponse> QuoteAsync(PromotionQuoteRequest request);

        // Khuyến mãi của một đơn: mã khách nhập (sai thì lỗi 400) hoặc khuyến mãi tự áp dụng tốt nhất
        Task<(Promotion? Promotion, decimal Discount)> ResolveAsync(
            string? code,
            decimal ticketAmount,
            int tickets,
            DateTime showStart);
    }
}
