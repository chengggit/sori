$ErrorActionPreference = 'Stop'
$project = (Resolve-Path "$PSScriptRoot/../..").Path
Set-Location $project
$prefix = Join-Path $project 'build/windows-install'
$stage = Join-Path $prefix 'bin'
& cmake --install build --prefix $prefix
if ($LASTEXITCODE -ne 0) { throw 'Application staging failed' }
Copy-Item resources/kiwi "$stage/kiwi" -Recurse -Force
Copy-Item "$env:MPV_ROOT/bin/*.dll" $stage -Force
foreach ($tool in @('ffmpeg', 'ffprobe')) {
    $binary = Get-ChildItem "$env:ChocolateyInstall/lib/ffmpeg" -Recurse -Filter "$tool.exe" | Select-Object -First 1
    if (!$binary) { throw "Cannot find real $tool executable" }
    Copy-Item $binary.FullName $stage -Force
}
& "$env:QT_ROOT_DIR/bin/windeployqt.exe" --release --qmldir qml "$stage/sori.exe"
if ($LASTEXITCODE -ne 0) { throw 'Qt deployment failed' }
New-Item -ItemType Directory -Force "$stage/licenses" | Out-Null
Copy-Item LICENSE, assets/*LICENSE*, assets/OFL-*.txt, assets/kiwi/*LICENSE "$stage/licenses/" -Force
$version = (& python -c "import tomllib; print(tomllib.load(open('core/Cargo.toml','rb'))['package']['version'])").Trim()
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^\d+\.\d+\.\d+([+-][0-9A-Za-z.-]+)?$') { throw 'Invalid application version' }
$compiler = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'
if (!(Test-Path $compiler)) { throw 'Inno Setup 6 is required (included in the Windows CI image)' }
& $compiler "/DStageDir=$stage" "/DOutputDir=$project/build" "/DAppVersion=$version" packaging/windows/sori.iss
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed' }
$installer = Join-Path $project "build/Sori-$version-windows-x86_64-setup-unsigned.exe"
if (!(Test-Path $installer)) { throw 'Installer artifact was not created' }
$hash = (Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($installer))" | Set-Content "$installer.sha256" -Encoding ascii
