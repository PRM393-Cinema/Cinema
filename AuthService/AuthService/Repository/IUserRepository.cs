using AuthService.Models;

namespace AuthService.Repository
{
    public interface IUserRepository
    {
        Task<User?> GetByEmailAsync(string email);
        Task<User?> GetByIdAsync(long id);
        Task<bool> ExistsByEmailAsync(string email);
        Task<Role?> GetRoleByNameAsync(string name);
        Task<List<User>> GetAllAsync();
        Task<User> AddAsync(User user);
        Task SaveChangesAsync();
    }
}
