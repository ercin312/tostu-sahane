# flutter_secure_storage_windows: ATL (atlstr.h) olmadan Windows build.
$root = Split-Path $PSScriptRoot -Parent
$pubFile = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev\flutter_secure_storage_windows-3.1.2\windows\flutter_secure_storage_windows_plugin.cpp"

if (-not (Test-Path $pubFile)) {
    Write-Error "Pub cache not found: $pubFile. Run 'flutter pub get' first."
    exit 1
}

$helpers = @'

namespace secure_storage_win {
std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int size = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (size <= 0) return std::wstring();
  std::wstring wide(static_cast<size_t>(size - 1), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), size);
  return wide;
}

std::string WideToUtf8(const wchar_t* wide) {
  if (wide == nullptr || wide[0] == L'\0') return std::string();
  int size = WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 0) return std::string();
  std::string utf8(static_cast<size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide, -1, utf8.data(), size, nullptr, nullptr);
  return utf8;
}
}

'@

# Her build oncesi temiz paketten basla.
$archive = Join-Path $root "tool\patches\flutter_secure_storage_windows_plugin.cpp.src"
if (-not (Test-Path (Split-Path $archive -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $archive -Parent) -Force | Out-Null
}
if (-not (Test-Path $archive)) {
    Copy-Item $pubFile $archive -Force
    Write-Host "Archived pristine plugin source."
}

Copy-Item $archive $pubFile -Force
$content = Get-Content $pubFile -Raw
$content = $content -replace '#include <atlstr\.h>\r?\n', ''
$content = $content -replace '#include <string>', "#include <string>`r`n$helpers"
$content = $content -replace 'const CA2W CREDENTIAL_FILTER\(\(ELEMENT_PREFERENCES_KEY_PREFIX \+ ''\*''\)\.c_str\(\)\);', 'const std::wstring CREDENTIAL_FILTER = secure_storage_win::Utf8ToWide(ELEMENT_PREFERENCES_KEY_PREFIX + ''*'');'
$content = $content -replace 'CREDENTIAL_FILTER\.m_psz', 'CREDENTIAL_FILTER.c_str()'
$content = $content -replace 'CA2W target_name\(\("key_" \+ ELEMENT_PREFERENCES_KEY_PREFIX\)\.c_str\(\)\);', 'const std::wstring target_name = secure_storage_win::Utf8ToWide("key_" + ELEMENT_PREFERENCES_KEY_PREFIX);'
$content = $content -replace 'CA2W target_name\(key\.c_str\(\)\);', 'const std::wstring target_name = secure_storage_win::Utf8ToWide(key);'
$content = $content -replace 'target_name\.m_psz', 'target_name.c_str()'
$content = $content -replace 'std::string target_name = CW2A\(pcred->TargetName\);', 'std::string target_name = secure_storage_win::WideToUtf8(pcred->TargetName);'
$content = $content -replace 'cred\.TargetName = target_name\.c_str\(\);', 'cred.TargetName = const_cast<LPWSTR>(target_name.c_str());'

Set-Content -Path $pubFile -Value $content -NoNewline
Write-Host "Patched (no ATL): $pubFile"
