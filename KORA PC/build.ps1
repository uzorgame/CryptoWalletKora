# Builds both Windows products and compiles the installer that carries them.
#
# One script, because the two apps ship together and a release where one is stale is worse
# than no release at all.
#
#   .\build.ps1              build both, then the installer
#   .\build.ps1 -SkipBuild   installer only, from whatever is already built

param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$wallet = Join-Path $root 'WALLET'
$market = Join-Path $root 'MARKET'

function Find-ISCC {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    )
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
    throw "Inno Setup 6 not found. Install it with: winget install JRSoftware.InnoSetup"
}

function Build-App([string]$path, [string]$name) {
    Write-Host "`n=== $name ===" -ForegroundColor Cyan
    Push-Location $path
    try {
        & flutter pub get | Out-Null
        & flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "$name failed to build" }
    } finally {
        Pop-Location
    }
}

# A running instance holds its own exe open, and the build failure that causes says nothing
# useful about why.
Get-Process kora_windows, kora_widget -ErrorAction SilentlyContinue | Stop-Process -Force

if (-not $SkipBuild) {
    Build-App $wallet  'KORA Wallet'
    Build-App $market  'KORA Market'
}

foreach ($exe in @(
    (Join-Path $wallet 'build\windows\x64\runner\Release\kora_windows.exe'),
    (Join-Path $market 'build\windows\x64\runner\Release\kora_widget.exe')
)) {
    if (-not (Test-Path -LiteralPath $exe)) { throw "Missing build output: $exe" }
}

Write-Host "`n=== Installer ===" -ForegroundColor Cyan
$iscc = Find-ISCC
Push-Location $wallet
try {
    & $iscc 'installer_combined.iss'
    if ($LASTEXITCODE -ne 0) { throw 'Installer failed to compile' }
} finally {
    Pop-Location
}

$output = Get-ChildItem (Join-Path $wallet 'installer_output') -Filter '*.exe' |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host "`nDone: $($output.FullName)  ($([math]::Round($output.Length/1MB,1)) MB)" -ForegroundColor Green
