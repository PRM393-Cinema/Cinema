<#
  Chia se file .env bang SOPS + age. Huong dan day du: docs/SECRETS_SOPS.md

    .\scripts\secrets.ps1 decrypt           Giai ma secrets.enc.env -> .env (chay sau khi pull)
    .\scripts\secrets.ps1 encrypt           Ma hoa .env -> secrets.enc.env (sau khi sua .env), roi commit secrets.enc.env
    .\scripts\secrets.ps1 check             So .env hien tai voi ban ma hoa (chi in ten bien khac nhau)
    .\scripts\secrets.ps1 add-key <age1...> Cap quyen giai ma cho thanh vien moi (can may da co quyen)
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('decrypt', 'encrypt', 'check', 'add-key')]
    [string]$Action,

    [Parameter(Position = 1)]
    [string]$PublicKey
)

$ErrorActionPreference = 'Stop'

# Duong dan tuyet doi: cac ham .NET khong theo Set-Location cua PowerShell
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$encrypted = Join-Path $root 'secrets.enc.env'
$plain = Join-Path $root '.env'
$config = Join-Path $root '.sops.yaml'
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

if (-not (Get-Command sops -ErrorAction SilentlyContinue)) {
    throw 'Chua cai sops: cai theo docs/SECRETS_SOPS.md muc 1, roi mo lai terminal.'
}

# Giai ma ra file tam (khong in noi dung ra man hinh), tra ve duong dan file tam
function Get-DecryptedTempFile {
    if (-not (Test-Path $encrypted)) { throw 'Khong co file secrets.enc.env.' }

    $tmp = [System.IO.Path]::GetTempFileName()
    & sops --config $config --decrypt --input-type dotenv --output-type dotenv --output $tmp $encrypted

    if ($LASTEXITCODE -ne 0) {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        throw 'Khong giai ma duoc: may nay chua co private key duoc cap quyen (xem docs/SECRETS_SOPS.md muc 2-3).'
    }

    return $tmp
}

# Doc file .env thanh bang KEY -> VALUE (bo qua comment, dong trong)
function Read-EnvValues([string]$path) {
    $values = @{}
    foreach ($line in [System.IO.File]::ReadAllLines($path)) {
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $values[$Matches[1]] = $Matches[2].TrimEnd("`r")
        }
    }
    return $values
}

# Ten cac bien khac nhau giua hai file .env (khong in gia tri)
function Get-ChangedKeys([string]$left, [string]$right) {
    $a = Read-EnvValues $left
    $b = Read-EnvValues $right
    $keys = @($a.Keys) + @($b.Keys) | Sort-Object -Unique
    return @($keys | Where-Object { $a[$_] -cne $b[$_] })
}

switch ($Action) {
    'decrypt' {
        $tmp = Get-DecryptedTempFile
        try {
            if (Test-Path $plain) {
                $changed = Get-ChangedKeys $plain $tmp
                if ($changed.Count -eq 0) {
                    Write-Host '.env da trung voi ban ma hoa, khong can doi.'
                    return
                }

                Copy-Item $plain "$plain.bak" -Force
                Write-Host "Cac bien thay doi: $($changed -join ', '). Da sao luu .env cu sang .env.bak"
            }

            Move-Item $tmp $plain -Force
            Write-Host 'Da giai ma secrets.enc.env -> .env. Chay lai: docker compose up -d'
        }
        finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    'encrypt' {
        if (-not (Test-Path $plain)) { throw 'Khong co file .env de ma hoa.' }

        # Noi dung khong doi thi giu nguyen file ma hoa (tranh diff vo nghia moi lan commit)
        if (Test-Path $encrypted) {
            try {
                $tmp = Get-DecryptedTempFile
                $changed = Get-ChangedKeys $plain $tmp
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue

                if ($changed.Count -eq 0) {
                    Write-Host 'Khong co gi thay doi so voi secrets.enc.env.'
                    return
                }

                Write-Host "Cac bien thay doi: $($changed -join ', ')"
            }
            catch {
                Write-Host 'Khong doc duoc ban ma hoa cu, se ma hoa lai tu .env hien tai.'
            }
        }

        # sops khong doc duoc dong ket thuc CRLF (.env tao tren Windows): chuyen sang LF trong file tam.
        # Ten file tam ket thuc bang .env de khop creation_rules trong .sops.yaml.
        $normalized = Join-Path ([System.IO.Path]::GetTempPath()) ("sops-" + [guid]::NewGuid().ToString('N') + '.env')
        try {
            $text = [System.IO.File]::ReadAllText($plain) -replace "`r`n", "`n"
            [System.IO.File]::WriteAllText($normalized, $text, $utf8NoBom)

            & sops --config $config --encrypt --input-type dotenv --output-type dotenv --output $encrypted $normalized
            if ($LASTEXITCODE -ne 0) { throw 'Ma hoa that bai (kiem tra .sops.yaml va noi dung .env).' }
        }
        finally {
            Remove-Item $normalized -Force -ErrorAction SilentlyContinue
        }

        Write-Host 'Da ma hoa .env -> secrets.enc.env. Commit secrets.enc.env (KHONG commit .env).'
    }

    'check' {
        if (-not (Test-Path $plain)) { throw 'Chua co file .env. Chay: .\scripts\secrets.ps1 decrypt' }

        $tmp = Get-DecryptedTempFile
        try {
            $changed = Get-ChangedKeys $plain $tmp
            if ($changed.Count -eq 0) {
                Write-Host 'KHOP: .env giong ban ma hoa trong repo.'
            }
            else {
                Write-Host "KHAC o cac bien: $($changed -join ', ')"
            }
        }
        finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    'add-key' {
        if ($PublicKey -notmatch '^age1[0-9a-z]{58}$') {
            throw 'Public key khong hop le (dang age1..., dai 62 ky tu).'
        }

        $lines = [System.Collections.Generic.List[string]]([System.IO.File]::ReadAllLines((Resolve-Path $config).Path))

        if (($lines -join "`n").Contains($PublicKey)) {
            Write-Host 'Key nay da co trong .sops.yaml.'
        }
        else {
            # Danh sach age trong .sops.yaml: moi dong mot key, cach nhau dau phay
            $last = -1
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match '^\s+age1[0-9a-z]+,?\s*$') { $last = $i }
            }
            if ($last -lt 0) { throw 'Khong tim thay danh sach age trong .sops.yaml.' }

            $indent = $lines[$last] -replace '^(\s+).*$', '$1'
            $lines[$last] = $lines[$last].TrimEnd().TrimEnd(',') + ','
            $lines.Insert($last + 1, "$indent$PublicKey")
            [System.IO.File]::WriteAllLines((Resolve-Path $config).Path, $lines, $utf8NoBom)
            Write-Host 'Da them key vao .sops.yaml'
        }

        & sops --config $config updatekeys --yes $encrypted
        if ($LASTEXITCODE -ne 0) { throw 'updatekeys that bai: may ban phai co private key dang duoc cap quyen.' }

        Write-Host 'Xong. Commit .sops.yaml va secrets.enc.env roi push/tao PR.'
    }
}
