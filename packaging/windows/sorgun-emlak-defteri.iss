#ifndef AppVersion
  #define AppVersion "1.0.7"
#endif

[Setup]
AppId={{A697141B-73DA-4F57-9E46-10B6C52833BC}
AppName=Sorgun Emlak Defteri
AppVersion={#AppVersion}
AppPublisher=Sorgun Emlak Defteri
AppPublisherURL=https://github.com/minitheguitarist/Sorgun-Emlak-Defteri
DefaultDirName={localappdata}\Programs\Sorgun Emlak Defteri
DefaultGroupName=Sorgun Emlak Defteri
DisableProgramGroupPage=yes
OutputDir=..\..\build\windows-installer
OutputBaseFilename=sorgun-emlak-defteri-v{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\sorgun_emlak_defteri.exe

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Sorgun Emlak Defteri"; Filename: "{app}\sorgun_emlak_defteri.exe"
Name: "{autodesktop}\Sorgun Emlak Defteri"; Filename: "{app}\sorgun_emlak_defteri.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Masaüstü kısayolu oluştur"; GroupDescription: "Ek kısayollar:"

[Run]
Filename: "{app}\sorgun_emlak_defteri.exe"; Description: "Sorgun Emlak Defteri'ni aç"; Flags: nowait postinstall skipifsilent
