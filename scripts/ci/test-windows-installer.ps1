$ErrorActionPreference = 'Stop'
$project = (Resolve-Path "$PSScriptRoot/../..").Path
$installer = Get-ChildItem "$project/build/Sori-*-windows-x86_64-setup-unsigned.exe"
if (@($installer).Count -ne 1) { throw 'Expected exactly one Windows installer' }
$installDir = Join-Path $env:RUNNER_TEMP 'sori-installer-check'
$log = Join-Path $project 'build/installer-check.log'
Write-Host 'Installing the packaged application'
$process = Start-Process $installer.FullName -Wait -PassThru -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
    "/DIR=`"$installDir`"", "/LOG=`"$log`""
)
if ($process.ExitCode -ne 0) { throw "Installer failed: $($process.ExitCode)" }
foreach ($file in @('sori.exe', 'QtWebEngineProcess.exe', 'ffmpeg.exe', 'ffprobe.exe',
                    'vulkan-1.dll', 'kiwi/lib/kiwi.dll', 'kiwi/models/cong/base/cong.mdl',
                    'helpers/sori-youtube-transcript/sori-youtube-transcript.exe')) {
    if (!(Test-Path (Join-Path $installDir $file))) { throw "Installed payload is missing: $file" }
}
try {
    $oldPath = $env:PATH
    $oldHelpDialogs = $env:QT_COMMAND_LINE_PARSER_NO_GUI_MESSAGE_BOXES
    # Verify installed Qt/mpv do not rely on the build machine's SDK PATH.
    $env:PATH = "$env:SystemRoot/System32;$env:SystemRoot"
    # A Windows GUI app otherwise shows --help in a modal dialog without a console.
    $env:QT_COMMAND_LINE_PARSER_NO_GUI_MESSAGE_BOXES = '1'
    Write-Host 'Checking the installed application without the SDK on PATH'
    $process = Start-Process "$installDir/sori.exe" -ArgumentList '--help' -PassThru
    if (!$process.WaitForExit(30000)) {
        Stop-Process -Id $process.Id -Force
        throw 'Installed application launch check timed out'
    }
    if ($process.ExitCode -ne 0) { throw 'Installed application launch check failed' }
    & "$installDir/ffmpeg.exe" -version | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Installed FFmpeg check failed' }
    $helper = & "$installDir/helpers/sori-youtube-transcript/sori-youtube-transcript.exe" --self-test
    if ($LASTEXITCODE -ne 0) { throw 'Installed transcript helper failed' }
    $helperResult = $helper | ConvertFrom-Json
    if (-not $helperResult.ready) { throw 'Installed transcript helper is not ready' }
} finally {
    $env:PATH = $oldPath
    $env:QT_COMMAND_LINE_PARSER_NO_GUI_MESSAGE_BOXES = $oldHelpDialogs
    $uninstaller = Join-Path $installDir 'unins000.exe'
    if (Test-Path $uninstaller) {
        Write-Host 'Uninstalling the packaged application'
        $process = Start-Process $uninstaller -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw 'Uninstaller failed' }
    }
}
if (Test-Path "$installDir/sori.exe") { throw 'Uninstaller left the installed executable behind' }
