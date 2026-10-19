; Installs the bundle `flutter build windows --release` leaves in
; build\windows\x64\runner\Release. Compiled by .github/workflows/release.yml,
; which defines AppVersion, SourcePath and OutputPath.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourcePath
  #define SourcePath "..\build\windows\x64\runner\Release"
#endif
#ifndef OutputPath
  #define OutputPath "..\build\installer"
#endif

[Setup]
AppId={{38ab0ce8-ec60-4017-b444-4ec35f0b58a4}
AppName=Yukari
AppVersion={#AppVersion}
AppPublisher=top.simonshiki
DefaultDirName={autopf}\Yukari
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
OutputDir={#OutputPath}
OutputBaseFilename=yukari-{#AppVersion}-windows-x64-setup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\yukari.exe

[Tasks]
Name: desktopicon; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourcePath}\*"; DestDir: "{app}"; Excludes: "*.pdb"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Yukari"; Filename: "{app}\yukari.exe"
Name: "{autodesktop}\Yukari"; Filename: "{app}\yukari.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\yukari.exe"; Description: "{cm:LaunchProgram,Yukari}"; Flags: nowait postinstall skipifsilent
