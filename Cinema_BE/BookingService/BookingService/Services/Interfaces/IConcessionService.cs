using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;

namespace BookingService.Services.Interfaces
{
    public interface IConcessionService
    {
        // Menu bắp nước; includeInactive cho Staff/Admin xem cả món đã ngừng bán
        Task<List<ConcessionItemResponse>> GetItemsAsync(bool includeInactive);

        Task<ConcessionItemResponse> CreateAsync(ConcessionItemRequest request);

        Task<ConcessionItemResponse> UpdateAsync(long id, ConcessionItemRequest request);
    }
}
