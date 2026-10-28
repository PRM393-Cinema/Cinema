using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Data;
using BookingService.Models;
using BookingService.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using static BookingService.Tests.Infrastructure.BookingApi;

namespace BookingService.Tests.Integration;

[Collection(BookingApiCollection.Name)]
public class MemberGiftTests(BookingApiFactory factory)
{
    private static long _next=45000;
    private async Task<(long,HttpClient)> Member(string tier)
    {
        var id=Interlocked.Increment(ref _next);
        await factory.ExecuteAsync<BookingDbContext>(async db=> {
            db.LoyaltyAccounts.Add(new LoyaltyAccount { UserId=id,Tier=tier,LifetimeSpend=tier=="VVIP"?5000000:2000000,CreatedAt=DateTime.Now,UpdatedAt=DateTime.Now });
            await db.SaveChangesAsync();
        });
        return (id,factory.ClientFor(TestJwt.Create(id,$"gift{id}@test.local","ROLE_CUSTOMER")));
    }

    [Fact]
    public async Task GrantsOnce_RenewsAfterSixMonths_AndUpgradeOnlyTopsUp()
    {
        var (id,client)=await Member("VIP");
        for(var i=0;i<2;i++) {
            var card=await client.GetFromJsonAsync<JsonElement>("/api/v1/loyalty/me");
            Assert.Equal(1,card.GetProperty("gifts").GetProperty("tickets").GetInt32());
        }
        await factory.ExecuteAsync<BookingDbContext>(async db=> {
            var a=await db.LoyaltyAccounts.FindAsync(id); a!.Tier="VVIP"; a.LifetimeSpend=5000000;
            var gift=await db.Set<MemberGift>().FindAsync(id); gift!.Tickets=0; gift.Combos=0;
            await db.SaveChangesAsync();
        });
        var upgraded=await client.GetFromJsonAsync<JsonElement>("/api/v1/loyalty/me");
        Assert.Equal(1,upgraded.GetProperty("gifts").GetProperty("tickets").GetInt32());
        await factory.ExecuteAsync<BookingDbContext>(async db=> {
            var gift=await db.Set<MemberGift>().FindAsync(id); gift!.RenewsAt=DateTime.Now.AddDays(-1);
            await db.SaveChangesAsync();
        });
        var renewed=await client.GetFromJsonAsync<JsonElement>("/api/v1/loyalty/me");
        Assert.Equal(2,renewed.GetProperty("gifts").GetProperty("tickets").GetInt32());
        Assert.Equal(2,renewed.GetProperty("gifts").GetProperty("combos").GetInt32());
    }

    [Fact]
    public async Task VvipFreeBookingConfirms_AndVipCannotUseStandardSeat()
    {
        var (_,client)=await Member("VVIP");
        var show=factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var seat=NewSeat();
        var booking=await CreateBookingAsync(client,show.Id,seat);
        var path=$"/api/v1/bookings/{booking.GetProperty("id").GetInt64()}/details";
        var result=await client.PutAsJsonAsync(path,new {showtimeId=show.Id,seats=new[]{new{seatId=seat}},useMemberGifts=true});
        Assert.Equal(HttpStatusCode.OK,result.StatusCode);
        var data=await result.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(0,data.GetProperty("totalAmount").GetDecimal());
        Assert.Equal("CONFIRMED",data.GetProperty("status").GetString());
        Assert.Equal(HttpStatusCode.Conflict,(await client.PutAsJsonAsync(path,new {showtimeId=show.Id,seats=new[]{new{seatId=seat}},useMemberGifts=true})).StatusCode);
        var (_,vip)=await Member("VIP");
        seat=NewSeat(); booking=await CreateBookingAsync(vip,show.Id,seat);
        result=await vip.PutAsJsonAsync($"/api/v1/bookings/{booking.GetProperty("id").GetInt64()}/details",new{showtimeId=show.Id,seats=new[]{new{seatId=seat}},useMemberGifts=true});
        Assert.Equal(HttpStatusCode.BadRequest,result.StatusCode);
    }

    [Fact]
    public async Task VipGiftsCoverVipSeatAndOneChosenCombo_ExcludeIndividualItems()
    {
        var (_,client)=await Member("VIP");
        var admin=factory.ClientFor(TestJwt.Create(1,"admin@test.local","ROLE_ADMIN"));
        async Task<long> Item(string name,decimal price) {
            var result=await admin.PostAsJsonAsync("/api/v1/concessions",new{name,price});
            result.EnsureSuccessStatusCode();
            return (await result.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetInt64();
        }
        var combo=await Item("Combo gift test",100000);
        var drink=await Item("Water gift test",20000);
        var show=factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var seat=NewSeat(); factory.Showtimes.SeatTypes[seat]="VIP";
        var booking=await CreateBookingAsync(client,show.Id,seat);
        var result=await client.PutAsJsonAsync($"/api/v1/bookings/{booking.GetProperty("id").GetInt64()}/details",new {
            showtimeId=show.Id,seats=new[]{new{seatId=seat}},useMemberGifts=true,
            concessions=new[]{new{itemId=combo,quantity=2},new{itemId=drink,quantity=1}}});
        result.EnsureSuccessStatusCode();
        var updated=await result.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(120000,updated.GetProperty("totalAmount").GetDecimal());
        var card=await client.GetFromJsonAsync<JsonElement>("/api/v1/loyalty/me");
        Assert.Equal(0,card.GetProperty("gifts").GetProperty("tickets").GetInt32());
        Assert.Equal(0,card.GetProperty("gifts").GetProperty("combos").GetInt32());
    }

    [Fact]
    public async Task ConcurrentOrdersCannotSpendTheSameGift()
    {
        var (user,client)=await Member("VVIP");
        await client.GetAsync("/api/v1/loyalty/me");
        await factory.ExecuteAsync<BookingDbContext>(async db=> {
            var gift=await db.Set<MemberGift>().FindAsync(user); gift!.Tickets=1;
            await db.SaveChangesAsync();
        });
        var show=factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var seats=new[]{NewSeat(),NewSeat()};
        var orders=new List<long>();
        foreach(var seat in seats) orders.Add((await CreateBookingAsync(client,show.Id,seat)).GetProperty("id").GetInt64());
        var responses=await Task.WhenAll(orders.Select((id,i)=>client.PutAsJsonAsync($"/api/v1/bookings/{id}/details",new {
            showtimeId=show.Id,seats=new[]{new{seatId=seats[i]}},useMemberGifts=true})));
        Assert.Single(responses,r=>r.StatusCode==HttpStatusCode.OK);
        Assert.Single(responses,r=>r.StatusCode==HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task HeldGiftsAreReservedOnce_AndReturnedOnCancel()
    {
        var (_,client)=await Member("VVIP");
        var show=factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var seats=new[]{NewSeat(),NewSeat(),NewSeat()};
        var booking=await CreateBookingAsync(client,show.Id,seats);
        var id=booking.GetProperty("id").GetInt64();
        for(var i=0;i<2;i++) Assert.Equal(HttpStatusCode.OK,(await client.PutAsJsonAsync($"/api/v1/bookings/{id}/details",new {showtimeId=show.Id,seats=seats.Select(s=>new{seatId=s}),useMemberGifts=true})).StatusCode);
        var card=await client.GetFromJsonAsync<JsonElement>("/api/v1/loyalty/me");
        Assert.Equal(0,card.GetProperty("gifts").GetProperty("tickets").GetInt32());
        Assert.Equal(HttpStatusCode.OK,(await client.PostAsync($"/api/v1/bookings/{id}/cancel",null)).StatusCode);
        card=await client.GetFromJsonAsync<JsonElement>("/api/v1/loyalty/me");
        Assert.Equal(2,card.GetProperty("gifts").GetProperty("tickets").GetInt32());
    }

    [Fact]
    public async Task ExpiryReturnsGifts_AndLatePaymentCannotReuseReleasedGifts()
    {
        var (_,client)=await Member("VVIP");
        var show=factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var seats=new[]{NewSeat(),NewSeat(),NewSeat()};
        var id=(await CreateBookingAsync(client,show.Id,seats)).GetProperty("id").GetInt64();
        (await client.PutAsJsonAsync($"/api/v1/bookings/{id}/details",new {
            showtimeId=show.Id,seats=seats.Select(s=>new{seatId=s}),useMemberGifts=true})).EnsureSuccessStatusCode();
        await factory.ExecuteAsync<BookingDbContext>(async db=> {
            var booking=await db.Bookings.FindAsync(id); booking!.ExpiresAt=DateTime.Now.AddMinutes(-1);
            await db.SaveChangesAsync();
        });
        await factory.ExecuteAsync<BookingService.Services.Interfaces.IBookingService>(async service=> {
            await service.ExpireOverdueBookingsAsync(100);
            await Assert.ThrowsAsync<BookingService.Exceptions.ConflictException>(()=>service.ConfirmPaidBookingAsync(id,null));
        });
        var card=await client.GetFromJsonAsync<JsonElement>("/api/v1/loyalty/me");
        Assert.Equal(2,card.GetProperty("gifts").GetProperty("tickets").GetInt32());
    }
}
