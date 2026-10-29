param([string]$XeLaTeX = 'xelatex', [int]$Passes = 3)
$ErrorActionPreference = 'Stop'
if ($Passes -lt 3) { throw 'Use at least three passes to resolve contents and table references.' }
$jobs = @(
    @('web-en', 'Cinema_Web_NET_SRS_EN'),
    @('web-vi', 'Cinema_Web_NET_SRS_VI'),
    @('mobile-en', 'Cinema_Mobile_SRS_EN'),
    @('mobile-vi', 'Cinema_Mobile_SRS_VI')
)
foreach ($job in $jobs) {
    Push-Location (Join-Path $PSScriptRoot $job[0])
    try {
        for ($passNumber = 1; $passNumber -le $Passes; $passNumber++) {
            & $XeLaTeX -no-shell-escape -interaction=nonstopmode -halt-on-error -file-line-error "-jobname=$($job[1])" main.tex *> build-console.txt
            if ($LASTEXITCODE -ne 0) {
                Get-Content -LiteralPath build-console.txt -Tail 25
                throw "XeLaTeX failed: $($job[1]), pass $passNumber"
            }
        }
        $log = Get-Content -LiteralPath "$($job[1]).log" -Raw
        if ($log -match 'Overfull|Missing character|undefined references|Rerun to get|Label\(s\) may have changed') {
            throw "Review unresolved layout/reference warnings in $($job[1]).log"
        }
        Write-Output "Built $($job[0])/$($job[1]).pdf"
    } finally { Pop-Location }
}
