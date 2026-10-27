using AuthService.Models;

namespace AuthService.Repository
{
    public interface IUserRepository
    {
        Task<User?> GetByEmailAsync(string email);
        Task<User?> GetByIdAsync(long id);
        Task<bool> ExistsByEmailAsync(string email);
        Task<Role?> GetRoleByNameAsync(string name);
        Task<List<Role>> GetRolesByNamesAsync(IEnumerable<string> names);
        Task<List<Role>> GetAllRolesAsync();
        // Khách hàng (ROLE_CUSTOMER) đang hoạt động có số điện thoại gồm đúng các chữ số này
        Task<List<User>> FindCustomersByPhoneDigitsAsync(string digits);

        Task<(List<User> Items, int TotalCount)> SearchAsync(string? keyword, string? role, bool? enabled, int page, int size);
        Task<User> AddAsync(User user);
        Task SaveChangesAsync();
    }
}
