# pubspec.yaml surumunu gunceller (Flutter Android/iOS surumlerini otomatik aktarir).
# Ornekler:
#   .\scripts\bump_version.ps1 -Version 1.2.0+3
#   .\scripts\bump_version.ps1 -Bump build
#   .\scripts\bump_version.ps1 -Bump patch
param(
    [string]$Version,
    [ValidateSet('major', 'minor', 'patch', 'build')]
    [string]$Bump
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$pubspecPath = Join-Path $PSScriptRoot '..\pubspec.yaml'
$content = Get-Content $pubspecPath -Raw

if ($content -notmatch '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
    throw "pubspec.yaml icinde version: MAJOR.MINOR.PATCH+BUILD bulunamadi."
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]
$build = [int]$Matches[4]

if ($Version) {
    if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)\+(\d+)$') {
        throw "Gecersiz surum formati. Beklenen: MAJOR.MINOR.PATCH+BUILD"
    }
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]
    $build = [int]$Matches[4]
}
elseif ($Bump) {
    switch ($Bump) {
        'major' { $major++; $minor = 0; $patch = 0; $build++ }
        'minor' { $minor++; $patch = 0; $build++ }
        'patch' { $patch++; $build++ }
        'build' { $build++ }
    }
}
else {
    throw "-Version veya -Bump parametresi gerekli."
}

$newVersion = "$major.$minor.$patch+$build"
$content = [regex]::Replace(
    $content,
    '(?m)^version:\s*.*$',
    "version: $newVersion"
)
Set-Content -Path $pubspecPath -Value $content -NoNewline

Write-Host "Surum guncellendi: $newVersion"
Write-Host "  versionName / CFBundleShortVersionString: $major.$minor.$patch"
Write-Host "  versionCode / CFBundleVersion: $build"
