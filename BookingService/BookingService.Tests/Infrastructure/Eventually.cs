namespace BookingService.Tests.Infrastructure;

public static class Eventually
{
    // Chờ điều kiện đúng (việc xử lý qua RabbitMQ chạy bất đồng bộ)
    public static async Task TrueAsync(Func<Task<bool>> condition, string because, int timeoutSeconds = 20)
    {
        var deadline = DateTime.UtcNow.AddSeconds(timeoutSeconds);

        while (DateTime.UtcNow < deadline)
        {
            if (await condition())
            {
                return;
            }

            await Task.Delay(250);
        }

        Assert.Fail($"Timed out after {timeoutSeconds}s waiting until {because}.");
    }
}
