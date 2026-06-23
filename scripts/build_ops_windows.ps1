# Restoran PC'sine kurulacak Windows operasyon paketini derler.
# Cikti: build\windows\x64\runner\Release\tostu_sahane.exe
Set-Location $PSScriptRoot\..
& "$PSScriptRoot\patch_windows_plugins.ps1"
flutter pub get
& "$PSScriptRoot\patch_windows_plugins.ps1"
& "$PSScriptRoot\patch_windows_ops_plugins.ps1"
flutter build windows --release --no-pub --dart-define=OPS_DESKTOP=true --dart-define=USE_MOCK_API=false
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$releaseDir = Join-Path (Get-Location) "build\windows\x64\runner\Release"
& "$PSScriptRoot\copy_vc_runtime_dlls.ps1" -TargetDir $releaseDir

Write-Host ""
$exe = Resolve-Path "build\windows\x64\runner\Release\tostu_sahane.exe"
Write-Host "Hazir:" $exe
Write-Host "Diger PC'ye kopyalarken Release klasorunun TAMAMINI alin (DLL + data)."