using BookingService.Data;
using BookingService.DTOs.Responses;
using BookingService.Exceptions;
using BookingService.Helpers;
using BookingService.Models;
using BookingService.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using BookingService.Clients.Interfaces;

namespace BookingService.Services.Implementations
{
    // Điểm thành viên. Mọi thay đổi điểm đều ghi một dòng loyalty_transactions; các thay đổi theo vé
    // tính từ các dòng đã ghi của vé đó nên gọi lại nhiều lần vẫn đúng.
    public class LoyaltyService : ILoyaltyService
    {
        private const int HistorySize = 50;

        private readonly BookingDbContext _context;
        private readonly IShowtimeClient _shows;

        public LoyaltyService(BookingDbContext context, IShowtimeClient shows)
        {
            _context = context;
            _shows = shows;
        }

        public async Task<LoyaltyResponse> GetAsync(long userId)
        {
            var gift=await new MemberGiftService(_context,_shows).GetAsync(userId);
            var account = await _context.LoyaltyAccounts
                .AsNoTracking()
                .FirstOrDefaultAsync(a => a.UserId == userId)
                ?? new LoyaltyAccount { UserId = userId };

            var history = await _context.LoyaltyTransactions
                .AsNoTracking()
                .Where(t => t.UserId == userId)
                .OrderByDescending(t => t.CreatedAt)
                .ThenByDescending(t => t.Id)
                .Take(HistorySize)
                .ToListAsync();

            var response = new LoyaltyResponse();
            Fill(response, account);
            response.Gifts=account.Tier=="MEMBER" ? null : gift;
            response.Transactions = history
                .Select(t => new LoyaltyTransactionResponse
                {
                    Id = t.Id,
                    Type = t.Type,
                    Points = t.Points,
                    BookingId = t.BookingId,
                    Note = t.Note,
                    CreatedAt = t.CreatedAt
                })
                .ToList();
            return response;
        }

        public async Task<List<LoyaltyAccountResponse>> GetAccountsAsync(IEnumerable<long> userIds)
        {
            var ids = userIds.Distinct().Take(100).ToList();
            var accounts = await _context.LoyaltyAccounts
                .AsNoTracking()
                .Where(a => ids.Contains(a.UserId))
                .ToDictionaryAsync(a => a.UserId);

            return ids
                .Select(id =>
                {
                    var response = new LoyaltyAccountResponse();
                    Fill(response, accounts.GetValueOrDefault(id) ?? new LoyaltyAccount { UserId = id });
                    return response;
                })
                .ToList();
        }

        public async Task<LoyaltyResponse> AdjustAsync(long userId, int points, string note, long actorId)
        {
            if (points == 0)
            {
                throw new BusinessException("Enter the points to add or take away.");
            }

            await using var transaction = await _context.Database.BeginTransactionAsync();
            var account = await LockAccountAsync(userId);
            if (account.Points + points < 0)
            {
                throw new BusinessException($"The customer only has {account.Points} points.");
            }

            Apply(account, "ADJUST", points, 0m, null, note.Trim(), actorId);
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            return await GetAsync(userId);
        }

        public async Task RedeemAsync(Booking booking, int points)
        {
            if (points <= 0)
            {
                return;
            }

            if (booking.UserId is not { } userId)
            {
                throw new BusinessException("Only members can use points. Find the customer's account first.");
            }

            var max = LoyaltyRules.MaxRedeemablePoints(booking.TotalAmount);
            if (points > max)
            {
                throw new BusinessException($"You can use at most {max} points on this booking (half of the price).");
            }

            var account = await LockAccountAsync(userId);
            if (points > account.Points)
            {
                throw new BusinessException($"You only have {account.Points} points.");
            }

            var discount = points * LoyaltyRules.PointValue;
            booking.PointsUsed = points;
            booking.PointsDiscount = discount;
            booking.TotalAmount -= discount;
            Apply(account, "REDEEM", -points, 0m, booking.Id, booking.BookingCode);
        }

        public async Task OnPaidAsync(Booking booking)
        {
            if (booking.UserId is not { } userId)
            {
                return;
            }

            var lines = await LinesOfAsync(booking.Id);
            var account = await LockAccountAsync(userId);

            // Tiền về sau khi vé đã hết hạn (điểm đã được trả lại): trừ lại điểm khách đã dùng,
            // nhưng không để điểm âm nếu khách đã tiêu số điểm đó
            var held = -lines.Where(t => t.Type is "REDEEM" or "RETURN").Sum(t => t.Points);
            var retake = Math.Min(booking.PointsUsed - held, account.Points);
            if (retake > 0)
            {
                Apply(account, "REDEEM", -retake, 0m, booking.Id, booking.BookingCode);
            }

            if (lines.Any(t => t.Type == "EARN"))
            {
                return;
            }

            // Điểm tính theo hạng trước khi cộng đơn này, trên số tiền thực trả
            var earned = LoyaltyRules.PointsEarned(booking.TotalAmount, account.Tier);
            booking.PointsEarned = earned;
            Apply(account, "EARN", earned, booking.TotalAmount, booking.Id, booking.BookingCode);
        }

        public async Task OnReleasedAsync(Booking booking)
        {
            await new MemberGiftService(_context,_shows).ReleaseAsync(booking);
            if (booking.UserId is not { } userId)
            {
                return;
            }

            var lines = await LinesOfAsync(booking.Id);
            var held = -lines.Where(t => t.Type is "REDEEM" or "RETURN").Sum(t => t.Points);
            var earned = lines.Where(t => t.Type is "EARN" or "REVERSE").Sum(t => t.Points);
            var spend = lines.Sum(t => t.SpendChange);
            if (held <= 0 && earned <= 0 && spend <= 0)
            {
                return;
            }

            var account = await LockAccountAsync(userId);
            if (held > 0)
            {
                Apply(account, "RETURN", held, 0m, booking.Id, booking.BookingCode);
            }

            if (earned > 0 || spend > 0)
            {
                // Điểm của vé đã được dùng vào đơn khác thì chỉ thu hồi phần còn lại (không để điểm âm)
                Apply(account, "REVERSE", -Math.Min(earned, account.Points), -spend, booking.Id, booking.BookingCode);
            }
        }

        // Khoá (FOR UPDATE) thẻ thành viên, tạo mới nếu khách chưa có
        private async Task<LoyaltyAccount> LockAccountAsync(long userId)
        {
            var now = DateTime.Now;
            await _context.Database.ExecuteSqlInterpolatedAsync($@"
                INSERT INTO loyalty_accounts (user_id, points, lifetime_spend, tier, created_at, updated_at)
                VALUES ({userId}, 0, 0, 'MEMBER', {now}, {now})
                ON CONFLICT (user_id) DO NOTHING");

            var account = await _context.LoyaltyAccounts
                .FromSqlInterpolated($"SELECT * FROM loyalty_accounts WHERE user_id = {userId} FOR UPDATE")
                .SingleAsync();

            // Đã có trong context từ trước (cùng request): lấy số liệu mới nhất
            await _context.Entry(account).ReloadAsync();
            return account;
        }

        private async Task<List<LoyaltyTransaction>> LinesOfAsync(long bookingId)
        {
            return await _context.LoyaltyTransactions
                .AsNoTracking()
                .Where(t => t.BookingId == bookingId)
                .ToListAsync();
        }

        private void Apply(
            LoyaltyAccount account,
            string type,
            int points,
            decimal spendChange,
            long? bookingId,
            string? note,
            long? createdBy = null)
        {
            var now = DateTime.Now;
            account.Points += points;
            account.LifetimeSpend = Math.Max(0m, account.LifetimeSpend + spendChange);
            account.Tier = LoyaltyRules.TierFor(account.LifetimeSpend);
            account.UpdatedAt = now;

            _context.LoyaltyTransactions.Add(new LoyaltyTransaction
            {
                UserId = account.UserId,
                BookingId = bookingId,
                Type = type,
                Points = points,
                SpendChange = spendChange,
                Note = note,
                CreatedBy = createdBy,
                CreatedAt = now
            });
        }

        private static void Fill(LoyaltyAccountResponse response, LoyaltyAccount account)
        {
            var next = LoyaltyRules.NextTier(account.Tier);
            response.UserId = account.UserId;
            response.Points = account.Points;
            response.PointValue = LoyaltyRules.PointValue;
            response.Tier = account.Tier;
            response.LifetimeSpend = account.LifetimeSpend;
            response.EarnRatePercent = LoyaltyRules.EarnRate(account.Tier) * 100m;
            response.NextTier = next?.Tier;
            response.NextTierSpend = next?.MinSpend;
        }
    }
}
