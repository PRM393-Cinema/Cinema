using BookingService.Data;
using BookingService.Models;
using BookingService.Exceptions;
using BookingService.Clients.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Services.Implementations;

// Shares the booking transaction and locks the member before reserving gifts.
public class MemberGiftService(BookingDbContext db, IShowtimeClient shows)
{
    public async Task<MemberGift?> GetAsync(long userId)
    {
        await using var tx = await db.Database.BeginTransactionAsync();
        var gift = await LockAsync(userId);
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        return gift;
    }

    private async Task<MemberGift?> LockAsync(long userId)
    {
        var account = await db.LoyaltyAccounts.FromSqlInterpolated(
            $"SELECT * FROM loyalty_accounts WHERE user_id={userId} FOR UPDATE").SingleOrDefaultAsync();
        if(account == null) return null;
        await db.Entry(account).ReloadAsync();
        var gift = await db.Set<MemberGift>().FindAsync(userId);
        if(gift!=null) await db.Entry(gift).ReloadAsync();
        if(account.Tier == "MEMBER") return gift;
        var now = DateTime.Now;
        if(gift == null)
        {
            gift = new MemberGift { UserId=userId, Tier=account.Tier, RenewsAt=now.AddMonths(6),
                Tickets=account.Tier=="VVIP"?2:1, Combos=account.Tier=="VVIP"?2:1 };
            db.Add(gift);
        }
        else if(now >= gift.RenewsAt)
        {
            // Unused gifts expire; no accumulation of missed cycles.
            while(gift.RenewsAt <= now) gift.RenewsAt=gift.RenewsAt.AddMonths(6);
            gift.Tier=account.Tier;
            gift.Tickets=gift.Combos=account.Tier=="VVIP"?2:1;
        }
        else if(account.Tier=="VVIP" && gift.Tier=="VIP")
        {
            // Upgrading tops up to the higher package in the same cycle.
            gift.Tier="VVIP";
            gift.Tickets++;
            gift.Combos++;
        }
        return gift;
    }

    public async Task ReleaseAsync(Booking booking)
    {
        var use=await db.Set<MemberGiftUse>().FindAsync(booking.Id);
        if(use==null) return;
        var gift=await LockAsync(use.UserId);
        if(gift!=null && gift.RenewsAt==use.RenewsAt)
        {
            gift.Tickets+=use.Tickets;
            gift.Combos+=use.Combos;
        }
        db.Remove(use);
    }

    public async Task<decimal> ReserveAsync(Booking booking, List<BookingSeat> seats, List<BookingConcession> snacks)
    {
        if(booking.UserId is not {} userId) throw new BusinessException("Sign in to use membership gifts.");
        var gift=await LockAsync(userId);
        if(gift==null || gift.RenewsAt<=DateTime.Now) throw new BusinessException("No membership gifts available.");
        var account=await db.LoyaltyAccounts.FindAsync(userId);
        if(account!.Tier=="MEMBER") throw new BusinessException("VIP or VVIP membership is required.");
        var types=await shows.GetSeatsAsync(booking.ShowtimeId,seats.Select(s=>s.SeatId).ToList());
        var eligible=seats.Where(s=>account.Tier=="VVIP" || types.Any(t=>t.SeatId==s.SeatId && t.SeatType=="VIP"))
            .OrderByDescending(s=>s.Price).Take(gift.Tickets).ToList();
        // shortcut: combos use the catalog's "Combo" name prefix; replace when the catalog gains a category field.
        var combos=snacks.Where(s=>s.ItemName.StartsWith("Combo",StringComparison.OrdinalIgnoreCase))
            .SelectMany(s=>Enumerable.Repeat(s.UnitPrice,s.Quantity)).OrderDescending().Take(gift.Combos).ToList();
        var discount=eligible.Sum(s=>s.Price)+combos.Sum();
        if(discount<=0) throw new BusinessException("Select an eligible seat or a combo to use your gifts.");
        gift.Tickets-=eligible.Count;
        gift.Combos-=combos.Count;
        db.Add(new MemberGiftUse { BookingId=booking.Id,UserId=userId,RenewsAt=gift.RenewsAt,
            Tickets=eligible.Count,Combos=combos.Count,Discount=discount });
        return discount;
    }
}
