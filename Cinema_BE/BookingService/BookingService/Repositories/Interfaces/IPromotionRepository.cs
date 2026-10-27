using BookingService.Models;

namespace BookingService.Repositories.Interfaces
{
    public interface IPromotionRepository
    {
        Task<List<Promotion>> GetAllAsync();

        Task<List<Promotion>> GetActiveAutomaticAsync();

        Task<Promotion?> GetByIdAsync(long id);

        Task<Promotion?> GetByCodeAsync(string code);

        Task<bool> CodeExistsAsync(string code, long? exceptId);

        Task AddAsync(Promotion promotion);

        Task IncrementUsageAsync(long id);

        Task SaveChangesAsync();
    }
}
