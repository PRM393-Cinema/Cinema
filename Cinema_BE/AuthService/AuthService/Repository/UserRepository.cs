using AuthService.Data;
using AuthService.Models;
using Microsoft.EntityFrameworkCore;

namespace AuthService.Repository
{
    public class UserRepository : IUserRepository
    {
        private readonly AuthDbContext _context;

        public UserRepository(AuthDbContext context)
        {
            _context = context;
        }

        public async Task<User?> GetByEmailAsync(string email)
        {
            return await _context.Users
                .Include(u => u.Roles)
                .FirstOrDefaultAsync(u => u.Email == email);
        }

        public async Task<User?> GetByIdAsync(long id)
        {
            return await _context.Users
                .Include(u => u.Roles)
                .FirstOrDefaultAsync(u => u.UserId == id);
        }

        public async Task<bool> ExistsByEmailAsync(string email)
        {
            return await _context.Users.AnyAsync(u => u.Email == email);
        }

        public async Task<Role?> GetRoleByNameAsync(string name)
        {
            return await _context.Roles.FirstOrDefaultAsync(r => r.Name == name);
        }

        public async Task<List<Role>> GetRolesByNamesAsync(IEnumerable<string> names)
        {
            return await _context.Roles
                .Where(r => names.Contains(r.Name))
                .ToListAsync();
        }

        public async Task<List<Role>> GetAllRolesAsync()
        {
            return await _context.Roles
                .AsNoTracking()
                .OrderBy(r => r.RoleId)
                .ToListAsync();
        }

        // Tìm theo email / họ tên / số điện thoại (không phân biệt hoa thường), lọc theo role và trạng thái
        public async Task<(List<User> Items, int TotalCount)> SearchAsync(
            string? keyword, string? role, bool? enabled, int page, int size)
        {
            var query = _context.Users.AsNoTracking().AsQueryable();

            if (!string.IsNullOrWhiteSpace(keyword))
            {
                var pattern = $"%{keyword.Trim()}%";
                query = query.Where(u =>
                    EF.Functions.ILike(u.Email, pattern) ||
                    (u.FullName != null && EF.Functions.ILike(u.FullName, pattern)) ||
                    (u.Phone != null && EF.Functions.ILike(u.Phone, pattern)));
            }

            if (!string.IsNullOrWhiteSpace(role))
            {
                query = query.Where(u => u.Roles.Any(r => r.Name == role));
            }

            if (enabled.HasValue)
            {
                query = query.Where(u => u.Enabled == enabled.Value);
            }

            var totalCount = await query.CountAsync();

            var items = await query
                .Include(u => u.Roles)
                .OrderBy(u => u.UserId)
                .Skip((page - 1) * size)
                .Take(size)
                .ToListAsync();

            return (items, totalCount);
        }

        public async Task<User> AddAsync(User user)
        {
            _context.Users.Add(user);
            await _context.SaveChangesAsync();
            return user;
        }

        public async Task SaveChangesAsync()
        {
            await _context.SaveChangesAsync();
        }
    }
}
