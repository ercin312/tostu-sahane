# Tostu Sahane Windows Ops - tek dosyalik Setup.exe uretir (Inno Setup).
# Kullanim:
#   .\scripts\create_windows_setup.ps1
#   .\scripts\create_windows_setup.ps1 -SkipBuild
#   .\scripts\create_windows_setup.ps1 -SkipPack
param(
    [switch]$SkipBuild,
    [switch]$SkipPack
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..

$pubspec = Get-Content 'pubspec.yaml' -Raw
if ($pubspec -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
    $appVersion = $Matches[1]
} else {
    $appVersion = '1.1.0'
}

$packDir = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Tostu Sahane Windows'
$distDir = Join-Path (Get-Location) 'dist\windows'
$iss = Join-Path (Get-Location) 'installer\windows\tostu_sahane_ops.iss'

Write-Host "=== Tostu Sahane Setup (v$appVersion) ==="

if (-not $SkipPack) {
    Write-Host "1) Release paketleniyor..."
    if ($SkipBuild) {
        & "$PSScriptRoot\pack_windows_desktop.ps1" -SkipBuild
    } else {
        & "$PSScriptRoot\pack_windows_desktop.ps1"
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    $exePath = Join-Path $packDir 'tostu_sahane.exe'
    if (-not (Test-Path $exePath)) {
        Write-Error "Paket yok: $packDir - once pack_windows_desktop.ps1 calistirin."
        exit 1
    }
}

$exePath = Join-Path $packDir 'tostu_sahane.exe'
if (-not (Test-Path $exePath)) {
    Write-Error "Setup kaynak klasoru eksik: $packDir"
    exit 1
}

function Find-Iscc {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
        'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'C:\Program Files\Inno Setup 6\ISCC.exe'
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$iscc = Find-Iscc
if (-not $iscc) {
    Write-Host "2) Inno Setup 6 bulunamadi - indiriliyor (sessiz kurulum)..."
    $tmp = Join-Path $env:TEMP 'innosetup-6.7.3.exe'
    $url = 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_3/innosetup-6.7.3.exe'
    try {
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
        $header = [IO.File]::ReadAllBytes($tmp)[0..1]
        if ($header[0] -ne 0x4D -or $header[1] -ne 0x5A) {
            throw 'Indirilen dosya gecerli bir exe degil.'
        }
    } catch {
        Write-Error @"
Inno Setup indirilemedi: $($_.Exception.Message)
Elle kurun: https://jrsoftware.org/isdl.php
Sonra tekrar: .\scripts\create_windows_setup.ps1 -SkipPack
"@
        exit 1
    }
    $proc = Start-Process -FilePath $tmp -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-' -Wait -PassThru
    if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
        Write-Warning "Inno Setup kurulum cikis kodu: $($proc.ExitCode)"
    }
    $iscc = Find-Iscc
    if (-not $iscc) {
        Write-Error "ISCC.exe hala bulunamadi. Inno Setup 6'yi elle kurun."
        exit 1
    }
}

Write-Host "3) Setup derleniyor: $iscc"
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

& $iscc `
    "/DMyAppVersion=$appVersion" `
    "/DSourceDir=$packDir" `
    "/DOutputDir=$distDir" `
    $iss

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$setup = Get-ChildItem $distDir -Filter "TostuSahane-Setup-*.exe" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $setup) {
    Write-Error "Setup.exe uretilemedi: $distDir"
    exit 1
}

$desktopSetup = Join-Path ([Environment]::GetFolderPath('Desktop')) $setup.Name
Copy-Item $setup.FullName -Destination $desktopSetup -Force

Write-Host ""
Write-Host "Hazir Setup:"
Write-Host "  $($setup.FullName)"
Write-Host "  $desktopSetup"
Write-Host ""
Write-Host "Diger PC: Setup.exe calistirin - Program Files'a kurar, masaustu kisayolu olusturur."
