$emulator = "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe"

# Không mở thêm nếu Pixel 8 Pro đang chạy
$running = Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -like "*Pixel_8_Pro*" }

if (-not $running) {
    Start-Process $emulator -ArgumentList "-avd Pixel_8_Pro -no-snapshot"
}

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class Win32Window {
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int X,
        int Y,
        int cx,
        int cy,
        uint uFlags
    );

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

Write-Host "Waiting for Pixel 8 Pro window..."

$window = $null

for ($i = 0; $i -lt 60; $i++) {

    $window = Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.MainWindowHandle -ne 0 -and
            $_.MainWindowTitle -like "*Pixel_8_Pro*"
        } |
        Select-Object -First 1

    if ($window) {
        break
    }

    Start-Sleep -Milliseconds 500
}

if ($window) {

    $h = [IntPtr]$window.MainWindowHandle

    # 9 = Restore
    [Win32Window]::ShowWindowAsync($h, 9) | Out-Null

    # X=80, Y=60, Width=400, Height=720
    [Win32Window]::SetWindowPos(
        $h,
        [IntPtr]::Zero,
        80,
        60,
        400,
        720,
        0x0040
    ) | Out-Null

    [Win32Window]::SetForegroundWindow($h) | Out-Null

    Write-Host "Pixel 8 Pro window restored."
}
else {
    Write-Host "Could not find emulator window."
}