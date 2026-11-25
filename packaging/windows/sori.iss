#ifndef StageDir
  #error StageDir must point to the deployed application directory
#endif
#ifndef OutputDir
  #error OutputDir must point to the build artifact directory
#endif
#ifndef AppVersion
  #error AppVersion must be supplied by the packaging script
#endif

[Setup]
AppId=com.sori.app
AppName=Sori
AppVersion={#AppVersion}
AppPublisher=Sori
DefaultDirName={localappdata}\Programs\Sori
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=Sori-{#AppVersion}-windows-x86_64-setup-unsigned
SetupIconFile=sori.ico
UninstallDisplayIcon={app}\sori.exe
LicenseFile=..\..\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Tasks]
Name: desktopicon; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Sori"; Filename: "{app}\sori.exe"
Name: "{autodesktop}\Sori"; Filename: "{app}\sori.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\sori.exe"; Description: "Launch Sori"; Flags: nowait postinstall skipifsilent
