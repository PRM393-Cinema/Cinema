using AuthService.Models;

namespace AuthService.Repository
{
    public interface IOtpCodeRepository
    {
        Task<OtpCode?> GetLatestAsync(long userId, string purpose);
        Task AddAsync(OtpCode otpCode);
        Task<bool> TryUseAttemptAsync(long id, int maxAttempts);
        Task<int> DeleteAsync(long userId, string purpose);
        Task SaveChangesAsync();
    }
}
