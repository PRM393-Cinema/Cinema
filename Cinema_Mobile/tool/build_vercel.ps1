[CmdletBinding()]
param(
    [string]$ApiBaseUrl = 'https://cinema-gateway.onrender.com',
    [string[]]$WakeUpUrls = @(
        'https://cinema-auth-gjyj.onrender.com/health',
        'https://cinema-movie-0ndy.onrender.com/health',
        'https://cinema-booking-cgjp.onrender.com/health',
        'https://cinema-gateway.onrender.com/health'
    )
)

$ErrorActionPreference = 'Stop'
$mobileRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$deployRoot = Join-Path $mobileRoot 'build\vercel'
$vercelRoot = Join-Path $deployRoot '.vercel'
$outputRoot = Join-Path $vercelRoot 'output'
$staticRoot = Join-Path $outputRoot 'static'
$configPath = Join-Path $outputRoot 'config.json'
$utf8 = New-Object System.Text.UTF8Encoding($false)

foreach ($address in @($ApiBaseUrl) + $WakeUpUrls) {
    $parsedAddress = $null
    if (-not [Uri]::TryCreate($address, [UriKind]::Absolute, [ref]$parsedAddress) -or
        $parsedAddress.Scheme -notin @('http', 'https')) {
        throw "Invalid public backend URL: $address"
    }
}

New-Item -ItemType Directory -Force -Path $vercelRoot | Out-Null
# Reuse the existing local project link without copying it into public assets.
$projectPath = Join-Path $vercelRoot 'project.json'
if (-not (Test-Path -LiteralPath $projectPath)) {
    foreach ($link in @('.vercel\project.json', 'build\cosmoq\.vercel\project.json')) {
        $linkPath = Join-Path $mobileRoot $link
        if (Test-Path -LiteralPath $linkPath) {
            Copy-Item -LiteralPath $linkPath -Destination $projectPath
            break
        }
    }
}
if (Test-Path -LiteralPath $configPath) { Remove-Item -LiteralPath $configPath }

Push-Location $mobileRoot
try {
    $defines = @(
        "--dart-define=API_BASE_URL=$($ApiBaseUrl.TrimEnd('/'))",
        "--dart-define=WAKE_UP_URLS=$($WakeUpUrls -join ',')"
    )
    & flutter build web --release --no-web-resources-cdn --base-href / --output $staticRoot @defines
    if ($LASTEXITCODE -ne 0) { throw 'Customer web build failed.' }
    & flutter build web --release --no-web-resources-cdn -t lib/main_admin.dart --base-href /admin/ --output (Join-Path $staticRoot 'admin') @defines
    if ($LASTEXITCODE -ne 0) { throw 'Admin web build failed.' }

    $config = @{
        version = 3
        routes = @(
            @{ src = '^/(.*)$'; headers = @{ 'Cache-Control' = 'public, max-age=0, must-revalidate' }; continue = $true },
            @{ src = '^/admin$'; status = 308; headers = @{ Location = '/admin/' } },
            @{ src = '^/$'; dest = '/index.html' },
            @{ src = '^/admin/$'; dest = '/admin/index.html' },
            @{ handle = 'filesystem' }
        )
    }
    [IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json -Depth 8), $utf8)
    Write-Output "Vercel package: $deployRoot"
    if (-not (Test-Path -LiteralPath $projectPath)) {
        Write-Output 'Link the Vercel project first: npx vercel link --cwd build/vercel'
    }
    Write-Output 'Deploy when ready: npx vercel deploy --prebuilt --prod --cwd build/vercel'
} finally {
    Pop-Location
}
