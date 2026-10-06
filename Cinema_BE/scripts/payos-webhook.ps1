<#
  Gia lap PayOS goi webhook "da thanh toan" cho mot don hang (test luong dat ve tren may, khong can tra tien that).
  Huong dan: docs/PAYOS.md

    .\scripts\payos-webhook.ps1 -OrderCode 15 -Amount 90000
    .\scripts\payos-webhook.ps1 -OrderCode 15 -Amount 90000 -BaseUrl http://localhost:5063

  OrderCode = id cua booking (orderCode tra ve khi tao link PayOS), Amount = totalAmount cua booking.
  Checksum key lay tu PAYOS_CHECKSUM_KEY trong .env (giong key BookingService dang dung) hoac tham so -ChecksumKey.
#>
param(
    [Parameter(Mandatory = $true)][long]$OrderCode,
    [Parameter(Mandatory = $true)][long]$Amount,
    [string]$BaseUrl = "http://localhost:5000",
    [string]$ChecksumKey = $env:PAYOS_CHECKSUM_KEY
)

$ErrorActionPreference = "Stop"

if (-not $ChecksumKey) {
    $envFile = Join-Path (Split-Path -Parent $PSScriptRoot) ".env"
    if (Test-Path $envFile) {
        $line = Get-Content $envFile | Where-Object { $_ -match '^\s*PAYOS_CHECKSUM_KEY\s*=' } | Select-Object -First 1
        if ($line) { $ChecksumKey = ($line -split '=', 2)[1].Trim().Trim('"') }
    }
}

if (-not $ChecksumKey) {
    throw "Chua co PayOS checksum key: dien PAYOS_CHECKSUM_KEY trong .env hoac truyen -ChecksumKey"
}

# Cac field cua "data" giong webhook PayOS that, sap theo ten a-z (thu tu dung de ky)
$data = [ordered]@{
    accountNumber          = "12345678"
    amount                 = $Amount
    code                   = "00"
    counterAccountBankId   = ""
    counterAccountBankName = ""
    counterAccountName     = ""
    counterAccountNumber   = ""
    currency               = "VND"
    desc                   = "success"
    description            = "SIMULATED$OrderCode"
    orderCode              = $OrderCode
    paymentLinkId          = "simulated-$OrderCode"
    reference              = "SIM$OrderCode"
    transactionDateTime    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    virtualAccountName     = ""
    virtualAccountNumber   = ""
}

$payload = ($data.Keys | ForEach-Object { "$_=$($data[$_])" }) -join "&"

$hmac = New-Object System.Security.Cryptography.HMACSHA256
$hmac.Key = [Text.Encoding]::UTF8.GetBytes($ChecksumKey)
$signature = -join ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($payload)) | ForEach-Object { $_.ToString("x2") })

$body = [ordered]@{
    code      = "00"
    desc      = "success"
    success   = $true
    data      = $data
    signature = $signature
} | ConvertTo-Json -Depth 3 -Compress

$url = "$($BaseUrl.TrimEnd('/'))/api/v1/payments/payos/webhook"
Write-Host "POST $url (order $OrderCode, amount $Amount)"

try {
    $result = Invoke-RestMethod -Method Post -Uri $url -ContentType "application/json; charset=utf-8" `
        -Body ([Text.Encoding]::UTF8.GetBytes($body))
    Write-Host "OK: $($result.message)"
}
catch {
    $detail = $_.ErrorDetails.Message
    if (-not $detail) { $detail = $_.Exception.Message }
    Write-Host "Loi: $detail" -ForegroundColor Red
    exit 1
}
