# Google Play / cihaz dagitimi icin Android release derlemesi.
# Play yuklemesi icin android/key.properties + upload keystore zorunludur.
# Ornekler:
#   .\scripts\build_android.ps1                 # AAB (varsayilan)
#   .\scripts\build_android.ps1 -Format apk
#   .\scripts\build_android.ps1 -BumpBuild      # build numarasini +1 yapip derle
#   .\scripts\build_android.ps1 -SkipSigningCheck  # yalnizca yerel test icin
param(
    [ValidateSet('apk', 'appbundle')]
    [string]$Format = 'appbundle',
    [switch]$BumpBuild,
    [switch]$SkipPubGet,
    [switch]$SkipSigningCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..

$keyProperties = Join-Path (Get-Location) 'android\key.properties'

if (-not $SkipSigningCheck) {
    if (-not (Test-Path $keyProperties)) {
        Write-Error @"
Google Play icin imzali release derlemesi yapilamadi: android/key.properties yok.

1. android/key.properties.example -> android/key.properties
2. Play Console'a kayitli upload-keystore.jks dosyasini android/ altina koyun
3. .\scripts\verify_android_signing.ps1 ile SHA1 dogrulayin
4. Tekrar: .\scripts\build_android.ps1
"@
    }

    & "$PSScriptRoot\verify_android_signing.ps1"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($BumpBuild) {
    & "$PSScriptRoot\bump_version.ps1" -Bump build
}

if (-not $SkipPubGet) {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$defines = @(
    '--dart-define=USE_MOCK_API=false'
)

Write-Host "Android release derlemesi basliyor ($Format)..."
if ($Format -eq 'appbundle') {
    flutter build appbundle --release @defines
}
else {
    flutter build apk --release @defines
}

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
if ($Format -eq 'appbundle') {
    $out = Resolve-Path 'build\app\outputs\bundle\release\app-release.aab'
}
else {
    $out = Resolve-Path 'build\app\outputs\flutter-apk\app-release.apk'
}
Write-Host "Hazir:" $out

if (-not $SkipSigningCheck) {
    Write-Host ""
    Write-Host "Yuklemeden once SHA1 tekrar dogrulandi. Play Console'a bu AAB'yi yukleyebilirsiniz."
}
