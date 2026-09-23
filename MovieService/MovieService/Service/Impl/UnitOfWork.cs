using Microsoft.EntityFrameworkCore.Storage;
using ShowtimeService.Data;
using ShowtimeService.Service.Interface;

namespace ShowtimeService.Service.Impl
{
    public class UnitOfWork : IUnitOfWork
    {
        private readonly ShowtimeDbContext _context;
        private IDbContextTransaction? _transaction;

        public UnitOfWork(ShowtimeDbContext context)
        {
            _context = context;
        }

        public async Task BeginTransactionAsync()
        {
            _transaction =
                await _context.Database.BeginTransactionAsync();
        }

        public async Task CommitTransactionAsync()
        {
            if (_transaction != null)
            {
                await _transaction.CommitAsync();
                await _transaction.DisposeAsync();
            }
        }

        public async Task RollbackTransactionAsync()
        {
            if (_transaction != null)
            {
                await _transaction.RollbackAsync();
                await _transaction.DisposeAsync();
            }
        }

        public async Task<int> SaveChangesAsync()
        {
            return await _context.SaveChangesAsync();
        }
    }
}
