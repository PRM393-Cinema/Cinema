using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Exceptions;
using BookingService.Mapping;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using BookingService.Services.Interfaces;

namespace BookingService.Services.Implementations
{
    public class ConcessionService : IConcessionService
    {
        private readonly IConcessionRepository _repository;

        public ConcessionService(IConcessionRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<ConcessionItemResponse>> GetItemsAsync(bool includeInactive)
        {
            return (await _repository.GetAllAsync(includeInactive))
                .Select(item => item.ToResponse())
                .ToList();
        }

        public async Task<ConcessionItemResponse> CreateAsync(ConcessionItemRequest request)
        {
            var item = new ConcessionItem
            {
                Name = request.Name!.Trim(),
                Description = Clean(request.Description),
                Price = request.Price!.Value,
                ImageUrl = Clean(request.ImageUrl),
                Active = request.Active ?? true,
                SortOrder = request.SortOrder ?? 0,
                CreatedAt = DateTime.Now
            };

            await _repository.AddAsync(item);
            await _repository.SaveChangesAsync();
            return item.ToResponse();
        }

        public async Task<ConcessionItemResponse> UpdateAsync(long id, ConcessionItemRequest request)
        {
            var item = await _repository.GetByIdAsync(id)
                ?? throw new NotFoundException($"Snack item {id} was not found.");

            item.Name = request.Name!.Trim();
            item.Description = Clean(request.Description);
            item.Price = request.Price!.Value;
            item.ImageUrl = Clean(request.ImageUrl);
            item.Active = request.Active ?? item.Active;
            item.SortOrder = request.SortOrder ?? item.SortOrder;

            await _repository.SaveChangesAsync();
            return item.ToResponse();
        }

        private static string? Clean(string? value)
        {
            return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
        }
    }
}
