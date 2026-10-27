using BookingService.Data;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Repositories.Impl
{
    public class PromotionRepository : IPromotionRepository
    {
        private readonly BookingDbContext _context;

        public PromotionRepository(BookingDbContext context)
        {
            _context = context;
        }

        public async Task<List<Promotion>> GetAllAsync()
        {
            return await _context.Promotions
                .AsNoTracking()
                .OrderByDescending(promotion => promotion.Active)
                .ThenByDescending(promotion => promotion.Id)
                .ToListAsync();
        }

        public async Task<List<Promotion>> GetActiveAutomaticAsync()
        {
            return await _context.Promotions
                .AsNoTracking()
                .Where(promotion => promotion.Active && promotion.Code == null)
                .OrderBy(promotion => promotion.Id)
                .ToListAsync();
        }

        public async Task<Promotion?> GetByIdAsync(long id)
        {
            return await _context.Promotions.FirstOrDefaultAsync(promotion => promotion.Id == id);
        }

        public async Task<Promotion?> GetByCodeAsync(string code)
        {
            return await _context.Promotions
                .AsNoTracking()
                .FirstOrDefaultAsync(promotion => promotion.Code == code);
        }

        public async Task<bool> CodeExistsAsync(string code, long? exceptId)
        {
            return await _context.Promotions
                .AnyAsync(promotion => promotion.Code == code && promotion.Id != exceptId);
        }

        public async Task AddAsync(Promotion promotion)
        {
            await _context.Promotions.AddAsync(promotion);
        }

        public async Task IncrementUsageAsync(long id)
        {
            await _context.Promotions
                .Where(promotion => promotion.Id == id)
                .ExecuteUpdateAsync(set => set.SetProperty(p => p.UsedCount, p => p.UsedCount + 1));
        }

        public async Task SaveChangesAsync()
        {
            await _context.SaveChangesAsync();
        }
    }
}
