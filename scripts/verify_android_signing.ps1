# Upload keystore SHA1 parmak izini Play Console ile karsilastirir.
param(
    [string]$KeyPropertiesPath = (Join-Path $PSScriptRoot '..\android\key.properties'),
    [string]$ExpectedSha1 = '5A:98:1A:E9:2D:E8:25:92:89:21:5A:23:9F:44:43:E8:60:06:64:17'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Normalize-Sha1 {
    param([string]$Value)
    return ($Value -replace '\s', '').ToUpperInvariant()
}

if (-not (Test-Path $KeyPropertiesPath)) {
    Write-Error @"
android/key.properties bulunamadi.

1. android/key.properties.example dosyasini android/key.properties olarak kopyalayin
2. Play Console'a kayitli upload-keystore.jks dosyasini android/ altina koyun
3. Sifreleri doldurup tekrar calistirin
"@
}

$props = @{}
Get-Content $KeyPropertiesPath | ForEach-Object {
    if ($_ -match '^\s*([^#=]+?)\s*=\s*(.+?)\s*$') {
        $props[$Matches[1]] = $Matches[2]
    }
}

foreach ($required in @('storeFile', 'storePassword', 'keyAlias')) {
    if (-not $props.ContainsKey($required) -or [string]::IsNullOrWhiteSpace($props[$required])) {
        throw "key.properties icinde '$required' eksik."
    }
}

$androidDir = Split-Path $KeyPropertiesPath -Parent
$storePath = Join-Path $androidDir $props['storeFile']
if (-not (Test-Path $storePath)) {
    throw "Keystore dosyasi bulunamadi: $storePath"
}

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool) {
    $candidates = @(
        'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe',
        'C:\Program Files\Java\*\bin\keytool.exe'
    )
    foreach ($pattern in $candidates) {
        $found = Get-ChildItem $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $keytool = $found.FullName
            break
        }
    }
}
if (-not $keytool) {
    throw "keytool bulunamadi. JDK veya Android Studio JBR kurulu olmali."
}
$keytoolPath = if ($keytool -is [string]) { $keytool } else { $keytool.Source }

$prevErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$outputLines = & $keytoolPath -list -v `
    -keystore $storePath `
    -alias $props['keyAlias'] `
    -storepass $props['storePassword'] 2>&1
$ErrorActionPreference = $prevErrorAction
$output = ($outputLines | Out-String)

if ($LASTEXITCODE -ne 0 -and $output -notmatch 'SHA1:') {
    throw "keytool basarisiz. Alias veya store sifresi yanlis olabilir.`n$output"
}

$sha1Line = $output | Select-String -Pattern 'SHA1:\s*(.+)' | Select-Object -First 1
if (-not $sha1Line) {
    throw "Keystore ciktisinda SHA1 bulunamadi."
}

$actualSha1 = $sha1Line.Matches[0].Groups[1].Value.Trim()
$expected = Normalize-Sha1 $ExpectedSha1
$actual = Normalize-Sha1 $actualSha1

Write-Host "Keystore :" $storePath
Write-Host "Alias    :" $props['keyAlias']
Write-Host "SHA1     :" $actualSha1

if ($actual -ne $expected) {
    Write-Error @"
YANLIS IMZA ANAHTARI

Play Console bekliyor : $ExpectedSha1
Secili keystore       : $actualSha1

Debug keystore ile derleme yapmayin. Play'e kayitli upload-keystore.jks dosyasini kullanin.
Keystore dosyasi yoksa Play Console > Kurulum > Uygulama butunlugu > Upload key sertifikasi
bolumunden yeni upload anahtari talep edebilirsiniz.
"@
}

Write-Host ""
Write-Host "OK: Upload keystore Play Console ile eslesiyor."
