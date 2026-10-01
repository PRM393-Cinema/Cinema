using AuthService.Data;
using AuthService.Models;
using Microsoft.EntityFrameworkCore;

namespace AuthService.Repository
{
    public class OtpCodeRepository : IOtpCodeRepository
    {
        private readonly AuthDbContext _context;

        public OtpCodeRepository(AuthDbContext context)
        {
            _context = context;
        }

        public async Task<OtpCode?> GetLatestAsync(long userId, string purpose)
        {
            return await _context.OtpCodes
                .AsNoTracking()
                .Where(o => o.UserId == userId && o.Purpose == purpose)
                .OrderByDescending(o => o.CreatedAt)
                .ThenByDescending(o => o.Id)
                .FirstOrDefaultAsync();
        }

        public async Task AddAsync(OtpCode otpCode)
        {
            await _context.OtpCodes.AddAsync(otpCode);
        }

        // Trừ một lượt nhập trước khi so mã, chỉ thành công khi mã còn lượt.
        // Là một câu UPDATE có điều kiện nên nhiều request song song cũng không vượt quá số lượt cho phép.
        public async Task<bool> TryUseAttemptAsync(long id, int maxAttempts)
        {
            var affected = await _context.OtpCodes
                .Where(o => o.Id == id && o.Attempts < maxAttempts)
                .ExecuteUpdateAsync(s => s.SetProperty(o => o.Attempts, o => o.Attempts + 1));

            return affected == 1;
        }

        public async Task<int> DeleteAsync(long userId, string purpose)
        {
            return await _context.OtpCodes
                .Where(o => o.UserId == userId && o.Purpose == purpose)
                .ExecuteDeleteAsync();
        }

        public async Task SaveChangesAsync()
        {
            await _context.SaveChangesAsync();
        }
    }
}
