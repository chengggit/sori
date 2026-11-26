$ErrorActionPreference = 'Stop'
$destination = Join-Path $env:GITHUB_WORKSPACE 'build-deps/mpv'
New-Item -ItemType Directory -Force $destination | Out-Null
$url = 'https://github.com/shinchiro/mpv-winbuild-cmake/releases/download/20261111/mpv-dev-x86_64-20261111-git-bcde6b93cc.7z'
$archive = Join-Path $env:RUNNER_TEMP 'mpv-dev.7z'
Invoke-WebRequest $url -OutFile $archive
if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne '273c079b11ea5575822f972756f4c9a71149a5c10130353abeb8586738938452') { throw 'mpv checksum mismatch' }
& 7z x $archive "-o$destination" -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'mpv extraction failed' }
$dll = Get-ChildItem $destination -Recurse -Filter '*mpv*.dll' | Select-Object -First 1
$header = Get-ChildItem $destination -Recurse -Filter 'client.h' | Where-Object { $_.Directory.Name -eq 'mpv' } | Select-Object -First 1
if (!$dll -or !$header) { throw 'mpv archive is missing DLL or headers' }
New-Item -ItemType Directory -Force "$destination/include", "$destination/lib", "$destination/bin" | Out-Null
if ([IO.Path]::GetFullPath($header.Directory.FullName) -ne [IO.Path]::GetFullPath("$destination/include/mpv")) { Copy-Item $header.Directory.FullName "$destination/include/mpv" -Recurse -Force }
Copy-Item $dll.FullName "$destination/bin/$($dll.Name)" -Force
# This mpv build imports vulkan-1.dll even when playback uses OpenGL. Ship the
# redistributable loader privately; do not require a machine-wide Vulkan SDK.
$runtimeArchive = Join-Path $env:RUNNER_TEMP 'vulkan-runtime.zip'
Invoke-WebRequest 'https://sdk.lunarg.com/sdk/download/1.4.363.0/windows/VulkanRT-X64-1.4.363.0-Components.zip' -OutFile $runtimeArchive
if ((Get-FileHash $runtimeArchive -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'a25a927aa8b9f0371048f1861cf88ac3b9bc9b1fb332c42d897c8ab32695769a') { throw 'Vulkan runtime checksum mismatch' }
$runtimeDir = Join-Path $env:RUNNER_TEMP 'vulkan-runtime'
Expand-Archive $runtimeArchive $runtimeDir -Force
$runtime = Join-Path $runtimeDir 'VulkanRT-X64-1.4.363.0-Components'
Copy-Item "$runtime/x64/vulkan-1.dll" "$destination/bin/" -Force
New-Item -ItemType Directory -Force "$destination/licenses" | Out-Null
Copy-Item "$runtime/VulkanRT-License.txt" "$destination/licenses/" -Force
$exports = & dumpbin /nologo /exports $dll.FullName
if ($LASTEXITCODE -ne 0) { throw 'dumpbin failed' }
$symbols = @($exports | ForEach-Object { if ($_ -match '^\s+\d+\s+[0-9A-F]+\s+[0-9A-F]+\s+(mpv_\w+)') { $Matches[1] } })
if ($symbols.Count -lt 20) { throw 'Could not read mpv exports' }
@("LIBRARY $($dll.Name)", 'EXPORTS') + $symbols | Set-Content "$destination/lib/mpv.def" -Encoding ascii
& lib.exe /nologo /machine:x64 "/def:$destination/lib/mpv.def" "/out:$destination/lib/mpv.lib"
if ($LASTEXITCODE -ne 0) { throw 'MSVC import library creation failed' }
"MPV_ROOT=$destination" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
"RUSTFLAGS=-Lnative=$destination/lib" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
"$destination/bin" | Out-File $env:GITHUB_PATH -Append -Encoding utf8
