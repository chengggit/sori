$ErrorActionPreference = 'Stop'
$project = (Resolve-Path "$PSScriptRoot/../..").Path
$installer = Get-ChildItem "$project/build/Sori-*-windows-x86_64-setup-unsigned.exe"
if (@($installer).Count -ne 1) { throw 'Expected exactly one Windows installer' }
$installDir = Join-Path $env:RUNNER_TEMP 'sori-installer-check'
$log = Join-Path $project 'build/installer-check.log'
$process = Start-Process $installer.FullName -Wait -PassThru -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
    "/DIR=`"$installDir`"", "/LOG=`"$log`""
)
if ($process.ExitCode -ne 0) { throw "Installer failed: $($process.ExitCode)" }
foreach ($file in @('sori.exe', 'QtWebEngineProcess.exe', 'ffmpeg.exe', 'ffprobe.exe',
                    'kiwi/lib/kiwi.dll', 'kiwi/models/cong/base/cong.mdl',
                    'helpers/sori-youtube-transcript/sori-youtube-transcript.exe')) {
    if (!(Test-Path (Join-Path $installDir $file))) { throw "Installed payload is missing: $file" }
}
try {
    $oldPath = $env:PATH
    # Verify installed Qt/mpv do not rely on the build machine's SDK PATH.
    $env:PATH = "$env:SystemRoot/System32;$env:SystemRoot"
    $process = Start-Process "$installDir/sori.exe" -ArgumentList '--help' -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw 'Installed application launch check failed' }
    & "$installDir/ffmpeg.exe" -version | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Installed FFmpeg check failed' }
    $helper = & "$installDir/helpers/sori-youtube-transcript/sori-youtube-transcript.exe" --self-test
    if ($LASTEXITCODE -ne 0) { throw 'Installed transcript helper failed' }
    $helperResult = $helper | ConvertFrom-Json
    if (-not $helperResult.ready) { throw 'Installed transcript helper is not ready' }
} finally {
    $env:PATH = $oldPath
    $uninstaller = Join-Path $installDir 'unins000.exe'
    if (Test-Path $uninstaller) {
        $process = Start-Process $uninstaller -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw 'Uninstaller failed' }
    }
}
if (Test-Path "$installDir/sori.exe") { throw 'Uninstaller left the installed executable behind' }
