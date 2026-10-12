using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Data;
using BookingService.Models;
using BookingService.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Tests.Integration;

[Collection(BookingApiCollection.Name)]
public class ManualNotificationTests(BookingApiFactory factory)
{
    private readonly HttpClient _staff = factory.ClientFor(TestJwt.Create(201, "staff@test.local", "ROLE_STAFF"));

    private async Task<long> CreateAsync(string recipient)
    {
        var response = await _staff.PostAsJsonAsync("/api/v1/notifications", new
        {
            userId = 101, recipientEmail = recipient,
            subject = "Manual notification", type = "GENERAL", content = "Hello"
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetInt64();
    }

    [Fact]
    public async Task ManualSendUpdatesOriginalRowAndRetryDoesNotSendAgain()
    {
        var recipient = $"manual-{Guid.NewGuid()}@test.local";
        var id = await CreateAsync(recipient);
        for (var attempt = 0; attempt < 2; attempt++)
        {
            var response = await _staff.PostAsync($"/api/v1/notifications/{id}/send", null);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var notification = await response.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal(id, notification.GetProperty("id").GetInt64());
            Assert.Equal("SENT", notification.GetProperty("status").GetString());
            Assert.NotEqual(JsonValueKind.Null, notification.GetProperty("sentAt").ValueKind);
        }
        Assert.Single(factory.Emails.To(recipient));
        Assert.Equal(1, await factory.QueryAsync<NotificationDbContext, int>(db =>
            db.Notifications.CountAsync(n => n.RecipientEmail == recipient && n.Status == "SENT")));
    }

    [Fact]
    public async Task LegacySuccessfulSendRepairsOriginalStatusWithoutAnotherEmail()
    {
        var recipient = $"legacy-{Guid.NewGuid()}@test.local";
        var id = await CreateAsync(recipient);
        await factory.QueryAsync<NotificationDbContext, int>(async db =>
        {
            db.Notifications.Add(new Notification
            {
                UserId = 101, RecipientEmail = recipient, Subject = "Manual notification",
                Type = "GENERAL", Content = "Hello", Status = "SENT",
                EventId = $"NOTIFICATION:{id}", SentAt = DateTime.Now, CreatedAt = DateTime.Now
            });
            return await db.SaveChangesAsync();
        });
        var response = await _staff.PostAsync($"/api/v1/notifications/{id}/send", null);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var notification = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(id, notification.GetProperty("id").GetInt64());
        Assert.Equal("SENT", notification.GetProperty("status").GetString());
        Assert.Empty(factory.Emails.To(recipient));
        Assert.Equal("SENT", await factory.QueryAsync<NotificationDbContext, string>(db =>
            db.Notifications.Where(n => n.Id == id).Select(n => n.Status).SingleAsync()));
    }
}
