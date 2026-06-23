# Masaustu dagitim paketini gunceller: build + Tostu Sahane Windows klasoru
param(
    [switch]$SkipBuild
)

Set-Location $PSScriptRoot\..

if (-not $SkipBuild) {
    Write-Host "Windows release derleniyor..."
    & "$PSScriptRoot\patch_windows_plugins.ps1"
    flutter pub get
    & "$PSScriptRoot\patch_windows_plugins.ps1"
    & "$PSScriptRoot\patch_windows_ops_plugins.ps1"
    flutter build windows --release --no-pub --dart-define=OPS_DESKTOP=true --dart-define=USE_MOCK_API=false
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$src = "build\windows\x64\runner\Release"
$dest = Join-Path ([Environment]::GetFolderPath('Desktop')) "Tostu Sahane Windows"

if (-not (Test-Path "$src\tostu_sahane.exe")) {
    Write-Host "HATA: Once derleme yapin: .\scripts\build_ops_windows.ps1"
    exit 1
}

if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
New-Item -ItemType Directory -Path $dest -Force | Out-Null

Get-ChildItem $src -File | Where-Object { $_.Extension -notin '.lib', '.exp' } |
    Copy-Item -Destination $dest -Force
Copy-Item -Path "$src\data" -Destination $dest -Recurse -Force

Write-Host "VC++ runtime DLL'leri pakete ekleniyor..."
& "$PSScriptRoot\copy_vc_runtime_dlls.ps1" -TargetDir $dest
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$redist = Join-Path $dest "vc_redist.x64.exe"
if (-not (Test-Path $redist)) {
    Write-Host "VC++ Redistributable indiriliyor..."
    try {
        Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vc_redist.x64.exe" -OutFile $redist -UseBasicParsing
    } catch {
        Write-Warning "vc_redist indirilemedi (ag/antivirus). Gerekirse elle ekleyin: https://aka.ms/vs/17/release/vc_redist.x64.exe"
    }
}

@'
================================================================================
  TOSTU SAHANE - WINDOWS KURULUM (Sadece 64-bit Windows 10/11)
================================================================================

ONEMLI: Tum klasoru oldugu gibi kopyalayin (sadece .exe degil).
         msvcp140.dll ve vcruntime140_1.dll klasorde olmali.

ADIMLAR (diger bilgisayarda):
  1) Tum "Tostu Sahane Windows" klasorunu kopyalayin
  2) "Tostu Sahane Baslat.bat" ile acin
  3) Hata devam ederse "1_VC_Runtime_Kur.bat" -> YONETICI olarak calistirin
  4) Acilmazsa "Sorun_Gider.bat" calistirin

SIK NEDENLER:
  - Sadece .exe kopyalandi (data/ ve DLL'ler eksik)
  - Visual C++ 2015-2022 (x64) yok (DLL'ler pakette olmali)
  - data klasoru kopyalanmamis
  - Antivirus engelliyor

ROLLER (giris ekraninda secin):
  - Sube Yoneticisi / Sube Personeli: e-posta + sifre (siparis onay, ic siparis listesi)
  - Garson: kullanici adi + sifre (masa siparisi; yonetici olusturur)
  - Garson ornek (Firestore'da yoksa): garson1 / Sahane123!

GARSON MODU:
  - Masa sec -> urun ekle -> "Icecek / Aparatif Ekle" -> siparis gonder
  - Ic siparis otomatik yazicidan cikar (masa + garson kodu, odeme satiri yok)
================================================================================
'@ | Set-Content -Path (Join-Path $dest "KURULUM.txt") -Encoding UTF8

@'
@echo off
chcp 65001 >nul
title Tostu Sahane - Visual C++ Kurulumu
echo.
echo Yonetici izni istenebilir. Diger PC'de acilmiyorsa mutlaka calistirin.
echo.
"%~dp0vc_redist.x64.exe" /install /passive /norestart
echo.
if %ERRORLEVEL% EQU 0 (echo VC++ tamam.) else (echo Hata kodu: %ERRORLEVEL% - Yonetici olarak deneyin.)
echo.
pause
'@ | Set-Content -Path (Join-Path $dest "1_VC_Runtime_Kur.bat") -Encoding ASCII

@'
@echo off
chcp 65001 >nul
title Tostu Sahane
cd /d "%~dp0"
if not exist "tostu_sahane.exe" (echo HATA: exe yok & pause & exit /b 1)
if not exist "data\flutter_assets" (echo HATA: data klasoru eksik & pause & exit /b 1)
echo Baslatiliyor...
"%~dp0tostu_sahane.exe"
set ERR=%ERRORLEVEL%
if %ERR% NEQ 0 (
  echo Uygulama acilamadi. Kod: %ERR%
  if %ERR% EQU -1073741795 (
    echo Bu kod genelde eski islemci veya ekran surucusu kaynaklidir.
    echo Sorun_Gider.bat calistirip boot_log.txt kontrol edin.
  )
  echo 1_VC_Runtime_Kur.bat dosyasini YONETICI olarak calistirin.
  pause
)
'@ | Set-Content -Path (Join-Path $dest "Tostu Sahane Baslat.bat") -Encoding ASCII

@'
@echo off
chcp 65001 >nul
title Tostu Sahane - Sorun Giderme
cd /d "%~dp0"
echo ===== Dosya kontrolu =====
for %%F in (tostu_sahane.exe flutter_windows.dll data\app.so data\icudtl.dat) do (
  if exist "%%F" (echo [OK] %%F) else (echo [EKSIK] %%F)
)
echo.
echo ===== Windows =====
systeminfo | findstr /B /C:"OS Name" /C:"OS Adi" /C:"System Type" /C:"Sistem Turu"
echo.
echo ===== VC++ Runtime =====
if exist "%SystemRoot%\System32\vcruntime140_1.dll" (echo [OK] vcruntime140_1) else (echo [EKSIK] vcruntime140_1)
if exist "%SystemRoot%\System32\msvcp140.dll" (echo [OK] msvcp140) else (echo [EKSIK] msvcp140)
echo.
echo ===== Test =====
if exist boot_log.txt del boot_log.txt
start "" "%~dp0tostu_sahane.exe"
timeout /t 5 /nobreak >nul
tasklist | find /I "tostu_sahane.exe" >nul
if %ERRORLEVEL% EQU 0 (
  echo [OK] Uygulama calisiyor.
) else (
  echo [HATA] Hemen kapandi.
  if exist boot_log.txt (
    echo.
    echo ===== boot_log.txt =====
    type boot_log.txt
    findstr /C:"first frame ok" boot_log.txt >nul
    if %ERRORLEVEL% EQU 0 (
      echo [OK] Ilk kare cizildi.
    ) else (
      echo [UYARI] runApp sonrasi cokme - ekran surucusu veya eski CPU olabilir.
    )
  ) else (
    echo boot_log.txt yok - Dart kodu baslamadan cokmus olabilir.
    echo verbose.txt olusturup Konsol_Baslat.bat deneyin.
  )
)
pause
'@ | Set-Content -Path (Join-Path $dest "Sorun_Gider.bat") -Encoding ASCII

@'
@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo. > verbose.txt
echo Konsol modu acik. Hata varsa asagida gorunur.
"%~dp0tostu_sahane.exe"
echo.
echo Cikis kodu: %ERRORLEVEL%
if exist boot_log.txt (
  echo.
  echo ===== boot_log.txt =====
  type boot_log.txt
)
pause
'@ | Set-Content -Path (Join-Path $dest "Konsol_Baslat.bat") -Encoding ASCII

Write-Host ""
Write-Host "Hazir:" $dest
