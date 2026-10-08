$deviceId = "emulator-5554"
$adbCommand = Get-Command adb -ErrorAction SilentlyContinue
$adb = if ($adbCommand) { $adbCommand.Source } else { Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe' }
if (-not (Test-Path $adb)) { throw "ADB was not found: $adb" }

$deviceOutput = & $adb devices
$connected = $deviceOutput | Select-String "^\s*$deviceId\s+device(?:\s|$)"
$deviceKnown = $deviceOutput | Select-String "^\s*$deviceId\s+(?:device|offline|unauthorized)(?:\s|$)"

# Không mở thêm nếu Pixel 8 Pro đang chạy
$running = Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -like "*Pixel_8_Pro*" }

if (-not $running -and -not $deviceKnown) {
    flutter emulators --launch Pixel_8_Pro
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Emulator launch returned an error; waiting in case Pixel 8 Pro is already starting." -ForegroundColor Yellow
    }
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

if (-not $connected) {
    Write-Host "Waiting for Pixel 8 Pro to finish booting (up to 120 seconds)..."
    for ($i = 0; $i -lt 120; $i++) {
        $deviceState = & $adb -s $deviceId get-state 2>$null
        $connected = ($LASTEXITCODE -eq 0 -and $deviceState.Trim() -eq 'device')
        if ($connected) { break }
        Start-Sleep -Seconds 1
    }
    if (-not $connected) {
        throw "Pixel 8 Pro did not become ready after 120 seconds. Check the emulator window."
    }
}

# Chỉ focus cửa sổ sau khi emulator boot xong; trước đó QEMU chưa có window handle.
Write-Host "Showing Pixel 8 Pro..."
$window = $null
for ($i = 0; $i -lt 40; $i++) {
    $window = Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.MainWindowHandle -ne 0 -and
            $_.MainWindowTitle -like "*Pixel_8_Pro*"
        } |
        Select-Object -First 1

    if ($window) { break }
    Start-Sleep -Milliseconds 500
}

if ($window) {
    $h = [IntPtr]$window.MainWindowHandle
    [Win32Window]::ShowWindowAsync($h, 9) | Out-Null
    [Win32Window]::SetWindowPos($h, [IntPtr]::Zero, 80, 60, 400, 720, 0x0040) | Out-Null
    [Win32Window]::SetForegroundWindow($h) | Out-Null
    Write-Host "Pixel 8 Pro window restored."
}
else {
    Write-Host "Could not find Pixel 8 Pro window." -ForegroundColor Yellow
}

$flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
$state = [hashtable]::Synchronized(@{ AppId = $null; LastDartChange = $null })
$eventNames = @('Changed', 'Created', 'Deleted', 'Renamed')
$libWatcher = [System.IO.FileSystemWatcher]::new((Join-Path $PSScriptRoot 'lib'), '*.dart')
$libWatcher.IncludeSubdirectories = $true
$libWatcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::Size

foreach ($eventName in $eventNames) {
    Register-ObjectEvent -InputObject $libWatcher -EventName $eventName -SourceIdentifier "FlutterDart.$eventName" -MessageData $state -Action {
        $Event.MessageData.LastDartChange = [DateTime]::UtcNow
    } | Out-Null
}

try {
    $libWatcher.EnableRaisingEvents = $true
    while ($true) {
        $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $processInfo.FileName = $env:ComSpec
        $commandLine = '"' + $flutterCommand + '" run --machine -d ' + $deviceId
        $processInfo.Arguments = '/d /s /c "' + $commandLine + '"'
        $processInfo.WorkingDirectory = $PSScriptRoot
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        $processInfo.RedirectStandardInput = $true
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true

        $flutter = [System.Diagnostics.Process]::new()
        $flutter.StartInfo = $processInfo
        $lines = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
        Register-ObjectEvent -InputObject $flutter -EventName OutputDataReceived -SourceIdentifier 'FlutterMachine.Output' -MessageData $lines -Action {
            if ($null -ne $Event.SourceEventArgs.Data) {
                $Event.MessageData.Enqueue([pscustomobject]@{ Stream = 'out'; Text = $Event.SourceEventArgs.Data })
            }
        } | Out-Null
        Register-ObjectEvent -InputObject $flutter -EventName ErrorDataReceived -SourceIdentifier 'FlutterMachine.Error' -MessageData $lines -Action {
            if ($null -ne $Event.SourceEventArgs.Data) {
                $Event.MessageData.Enqueue([pscustomobject]@{ Stream = 'err'; Text = $Event.SourceEventArgs.Data })
            }
        } | Out-Null

        if (-not $flutter.Start()) { throw 'Could not start Flutter.' }
        $flutter.BeginOutputReadLine()
        $flutter.BeginErrorReadLine()
        Write-Host 'Starting Flutter. Dart files under lib will hot reload when saved.'

        $state.AppId = $null
        $state.LastDartChange = $null
        $requestId = 1
        while (-not $flutter.HasExited) {
            $line = $null
            while ($lines.TryDequeue([ref]$line)) {
                if ($line.Stream -eq 'err') {
                    Write-Host $line.Text -ForegroundColor Red
                    continue
                }

                try {
                    $message = $line.Text | ConvertFrom-Json -ErrorAction Stop
                }
                catch {
                    Write-Host $line.Text
                    continue
                }

                if ($null -ne $message.id) {
                    if ($null -ne $message.error) {
                        Write-Host "Hot reload failed: $($message.error)" -ForegroundColor Red
                    }
                    elseif ($message.result.message) {
                        $color = if ($message.result.code -eq 0) { 'Green' } else { 'Yellow' }
                        Write-Host $message.result.message -ForegroundColor $color
                    }
                    continue
                }

                switch ($message.event) {
                    'app.start' {
                        $state.AppId = $message.params.appId
                        Write-Host 'App started. Save a Dart file to update the emulator automatically.' -ForegroundColor Green
                    }
                    'app.progress' {
                        if ($message.params.message) { Write-Host $message.params.message }
                    }
                    'app.started' { Write-Host 'Flutter app is ready.' -ForegroundColor Green }
                    'app.log' {
                        if ($message.params.log) {
                            $color = if ($message.params.error) { 'Red' } else { 'Gray' }
                            Write-Host $message.params.log -ForegroundColor $color
                        }
                    }
                    'app.stop' {
                        if ($message.params.error) { Write-Host $message.params.error -ForegroundColor Red }
                    }
                }
            }

            if ($state.AppId -and $state.LastDartChange -and
                ([DateTime]::UtcNow - $state.LastDartChange).TotalMilliseconds -ge 1000) {
                $state.LastDartChange = $null
                $request = @{
                    id = $requestId++
                    method = 'app.restart'
                    params = @{
                        appId = $state.AppId
                        fullRestart = $false
                        pause = $false
                        reason = 'Dart file saved'
                        debounce = $true
                    }
                } | ConvertTo-Json -Compress -Depth 4
                $flutter.StandardInput.WriteLine($request)
                $flutter.StandardInput.Flush()
                Write-Host 'Dart change detected; hot reloading...' -ForegroundColor Cyan
            }

            Start-Sleep -Milliseconds 100
        }

        $flutter.WaitForExit()
        $exitCode = $flutter.ExitCode
        Unregister-Event -SourceIdentifier 'FlutterMachine.Output' -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier 'FlutterMachine.Error' -ErrorAction SilentlyContinue
        $flutter.Dispose()
        $flutter = $null
        if ($exitCode -ne 0) { throw "Flutter exited with code $exitCode." }

        Write-Host 'Flutter lost its device connection. Restarting the app in 3 seconds...' -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }
}
finally {
    $libWatcher.EnableRaisingEvents = $false
    $libWatcher.Dispose()
    foreach ($eventName in $eventNames) {
        Unregister-Event -SourceIdentifier "FlutterDart.$eventName" -ErrorAction SilentlyContinue
    }
    Unregister-Event -SourceIdentifier 'FlutterMachine.Output' -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier 'FlutterMachine.Error' -ErrorAction SilentlyContinue
    if ($flutter) {
        if (-not $flutter.HasExited) { $flutter.Kill() }
        $flutter.Dispose()
    }
}
