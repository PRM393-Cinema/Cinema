param([string]$Compiler = 'tectonic')
$ErrorActionPreference = 'Stop'
foreach ($paper in @('ieee-web', 'ieee-mobile')) {
    Push-Location (Join-Path $PSScriptRoot $paper)
    try {
        & $Compiler --keep-logs --keep-intermediates main.tex
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $paper" }
        $log = Get-Content main.log -Raw
        if ($log -match 'Overfull|undefined references|undefined citations|Missing character') {
            throw "Review layout or reference warnings: $paper/main.log"
        }
    } finally { Pop-Location }
}
