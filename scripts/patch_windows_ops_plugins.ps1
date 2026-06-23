# Windows ops paketi: native Firestore/Firebase eklentilerini cikarir.
# Eski CPU / GPU suruculerinde STATUS_ILLEGAL_INSTRUCTION (0xC000001D) riskini azaltir.
$root = Split-Path $PSScriptRoot -Parent

$registrant = Join-Path $root "windows\flutter\generated_plugin_registrant.cc"
$cmake = Join-Path $root "windows\flutter\generated_plugins.cmake"

if (-not (Test-Path $registrant)) {
    Write-Error "Once 'flutter pub get' calistirin."
    exit 1
}

$removePlugins = @(
    'cloud_firestore',
    'firebase_core',
    'audioplayers_windows',
    'geolocator_windows',
    'share_plus'
)

# --- generated_plugin_registrant.cc ---
$cc = Get-Content $registrant -Raw
foreach ($plugin in $removePlugins) {
    $cc = $cc -replace "(?m)^#include <${plugin}/.*\r?\n", ''
}
$cc = $cc -replace '(?ms)^\s*CloudFirestorePluginCApiRegisterWithRegistrar\(.*?\);\s*\r?\n', ''
$cc = $cc -replace '(?ms)^\s*FirebaseCorePluginCApiRegisterWithRegistrar\(.*?\);\s*\r?\n', ''
$cc = $cc -replace '(?ms)^\s*AudioplayersWindowsPluginRegisterWithRegistrar\(.*?\);\s*\r?\n', ''
$cc = $cc -replace '(?ms)^\s*GeolocatorWindowsRegisterWithRegistrar\(.*?\);\s*\r?\n', ''
$cc = $cc -replace '(?ms)^\s*SharePlusWindowsPluginCApiRegisterWithRegistrar\(.*?\);\s*\r?\n', ''
Set-Content -Path $registrant -Value $cc -NoNewline

# --- generated_plugins.cmake ---
if (Test-Path $cmake) {
    $cmakeContent = Get-Content $cmake -Raw
    foreach ($plugin in $removePlugins) {
        $cmakeContent = $cmakeContent -replace "(?m)^\s*${plugin}\s*\r?\n", ''
    }
    $cmakeContent = $cmakeContent -replace '(?ms)\s*foreach\(ffi_plugin \$\{FLUTTER_FFI_PLUGIN_LIST\}\).*?endforeach\(ffi_plugin\)', ''
    $cmakeContent = $cmakeContent -replace '(?m)^list\(APPEND FLUTTER_FFI_PLUGIN_LIST\s*\r?\n\s*jni\s*\r?\n\)\s*\r?\n', ''
    Set-Content -Path $cmake -Value $cmakeContent -NoNewline
}

Write-Host "Ops Windows eklenti yamasi uygulandi (Firestore/Firebase native kaldirildi)."
