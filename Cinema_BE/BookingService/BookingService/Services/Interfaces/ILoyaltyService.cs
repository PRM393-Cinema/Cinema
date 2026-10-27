using BookingService.DTOs.Responses;
using BookingService.Models;

namespace BookingService.Services.Interfaces
{
    public interface ILoyaltyService
    {
        Task<LoyaltyResponse> GetAsync(long userId);

        // Thẻ thành viên của nhiều khách (khách chưa có điểm: 0 điểm, hạng MEMBER)
        Task<List<LoyaltyAccountResponse>> GetAccountsAsync(IEnumerable<long> userIds);

        Task<LoyaltyResponse> AdjustAsync(long userId, int points, string note, long actorId);

        // Các hàm dưới chạy trong transaction của booking.

        // Dùng điểm khi tạo đơn: trừ điểm, giảm tổng tiền
        Task RedeemAsync(Booking booking, int points);

        // Vé đã thanh toán: cộng điểm theo hạng, tăng tổng chi tiêu
        Task OnPaidAsync(Booking booking);

        // Vé không thành (hết hạn / huỷ / hoàn tiền): trả điểm đã dùng, thu hồi điểm đã cộng
        Task OnReleasedAsync(Booking booking);
    }
}
