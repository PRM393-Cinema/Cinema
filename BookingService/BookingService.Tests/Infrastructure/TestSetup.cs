using System.Runtime.CompilerServices;

namespace BookingService.Tests.Infrastructure;

internal static class TestSetup
{
    // Chạy trước mọi test của assembly
    [ModuleInitializer]
    internal static void Initialize()
    {
        // Giống Program.cs: schema dùng 'timestamp without time zone' với giờ local
        AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);

        // Không dùng container dọn dẹp (Ryuk) của Testcontainers để khỏi tải thêm image:
        // các container test đều được dừng trong DisposeAsync
        if (Environment.GetEnvironmentVariable("TESTCONTAINERS_RYUK_DISABLED") is null)
        {
            Environment.SetEnvironmentVariable("TESTCONTAINERS_RYUK_DISABLED", "true");
        }
    }
}
