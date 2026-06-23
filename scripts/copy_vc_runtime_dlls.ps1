# Visual C++ 2015-2022 x64 runtime DLL'lerini hedef klasore kopyalar.
# Baska PC'de msvcp140.dll / vcruntime140_1.dll hatasini onler.
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$required = @(
    'msvcp140.dll',
    'vcruntime140.dll',
    'vcruntime140_1.dll'
)
$optional = @(
    'msvcp140_1.dll',
    'msvcp140_2.dll',
    'concrt140.dll'
)

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

function Find-VcRuntimeDll {
    param([string]$Name)

    $searchRoots = @(
        (Join-Path $PSScriptRoot '..\third_party\vc_redist\x64'),
        (Join-Path $env:TEMP 'tostu_sahane_vcredist\x64')
    )

    foreach ($root in $searchRoots) {
        if (-not (Test-Path $root)) { continue }
        $hit = Get-ChildItem -Path $root -Recurse -Filter $Name -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }

    $vsRoots = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\*\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\*\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT"
    )
    foreach ($pattern in $vsRoots) {
        $dirs = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending
        foreach ($dir in $dirs) {
            $candidate = Join-Path $dir.FullName $Name
            if (Test-Path $candidate) { return $candidate }
        }
    }

    $system = Join-Path $env:SystemRoot "System32\$Name"
    if (Test-Path $system) { return $system }

    return $null
}

function Ensure-VcRedistExtracted {
    $extractRoot = Join-Path $env:TEMP 'tostu_sahane_vcredist'
    $marker = Join-Path $extractRoot 'extracted.ok'
    if (Test-Path $marker) { return }

    $installer = Join-Path $PSScriptRoot '..\third_party\vc_redist\vc_redist.x64.exe'
    if (-not (Test-Path $installer)) {
        $cacheDir = Join-Path $PSScriptRoot '..\third_party\vc_redist'
        if (-not (Test-Path $cacheDir)) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        }
        $installer = Join-Path $cacheDir 'vc_redist.x64.exe'
        if (-not (Test-Path $installer)) {
            Write-Host "VC++ Redistributable indiriliyor..."
            Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' `
                -OutFile $installer -UseBasicParsing
        }
    }

    if (-not (Test-Path $installer)) { return }

    if (Test-Path $extractRoot) {
        Remove-Item $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null

    Write-Host "VC++ paketi aciliyor (extract)..."
    $proc = Start-Process -FilePath $installer `
        -ArgumentList "/extract:$extractRoot", '/q' `
        -PassThru -Wait
    if ($proc.ExitCode -eq 0) {
        New-Item -ItemType File -Path $marker -Force | Out-Null
    }
}

Ensure-VcRedistExtracted

$copied = @()
$missing = @()

foreach ($name in ($required + $optional)) {
    $source = Find-VcRuntimeDll -Name $name
    if (-not $source) {
        if ($required -contains $name) { $missing += $name }
        continue
    }
    Copy-Item -Path $source -Destination (Join-Path $TargetDir $name) -Force
    $copied += $name
}

Write-Host "VC runtime DLL hedef: $TargetDir"
foreach ($name in $copied) {
    Write-Host "  [OK] $name"
}

if ($missing.Count -gt 0) {
    Write-Error @"
Zorunlu VC++ DLL bulunamadi: $($missing -join ', ')
Bu makinede Visual C++ Redistributable veya Visual Studio Build Tools kurulu olmali.
Alternatif: hedef PC'de 1_VC_Runtime_Kur.bat calistirin.
"@
}
