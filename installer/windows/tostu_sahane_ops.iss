; Tostu Sahane — Windows şube/yönetici masaüstü kurulum
; Derleme: scripts\create_windows_setup.ps1 (ISCC ile)

#ifndef MyAppVersion
  #define MyAppVersion "1.1.0"
#endif

#ifndef SourceDir
  #define SourceDir "..\\..\\build\\windows\\x64\\runner\\Release"
#endif

#ifndef OutputDir
  #define OutputDir "..\\..\\dist\\windows"
#endif

#define MyAppName "Tostu Sahane"
#define MyAppNameFull "Tostu Sahane (Şube / Yönetici)"
#define MyAppPublisher "Tostu Sahane"
#define MyAppExeName "tostu_sahane.exe"
#define MyAppId "TostuSahane.OpsDesktop"

[Setup]
AppId={#MyAppId}
AppName={#MyAppNameFull}
AppVersion={#MyAppVersion}
AppVerName={#MyAppNameFull} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=TostuSahane-Setup-{#MyAppVersion}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
CloseApplications=yes
RestartApplications=no
InfoBeforeFile=info_before.txt
LicenseFile=
DisableWelcomePage=no

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
; Uygulama (Release klasörü — lib/exp hariç pack script ile hazırlanmış hedef tercih edilir)
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.lib,*.exp,*.pdb"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
; VC++ 2015-2022 x64 (pakette varsa sessiz kur)
Filename: "{app}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Visual C++ Runtime kuruluyor..."; Flags: waituntilterminated skipifdoesntexist; Check: NeedsVcRedist
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[Code]
function NeedsVcRedist: Boolean;
begin
  Result := not FileExists(ExpandConstant('{sys}\vcruntime140_1.dll'));
end;
