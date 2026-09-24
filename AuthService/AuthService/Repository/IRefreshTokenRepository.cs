using AuthService.Models;

namespace AuthService.Repository
{
    public interface IRefreshTokenRepository
    {
        Task<RefreshToken?> GetByTokenAsync(string token);
        Task AddAsync(RefreshToken token);
        Task SaveChangesAsync();
    }
}
