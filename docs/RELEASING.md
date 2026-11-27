# Builds and releases

This guide is for repository maintainers preparing and publishing Sori releases.
It covers CI artifacts, packaging, and checks before distribution. You don't
need to follow these steps to submit a normal pull request.

For local setup and testing, see [DEVELOPING.md](../DEVELOPING.md). For PR guidance,
see [CONTRIBUTING.md](../CONTRIBUTING.md).

## CI artifacts

[Desktop builds](../.github/workflows/build.yml) runs on pushes to `main`, version
tags, pull requests, and manual dispatch, using Qt 6.10.2.

- **Pull requests and main:** build and test on all three platforms, without Rust optimization,
  caption-helper bundling, or installers. Caption logic is still tested in Python.
  Main also warms caches for future PRs.
- **Documentation-only changes:** quick status checks pass without platform
  setup, builds, or tests. This covers root Markdown files, `docs/`, release
  notes, and the QML test README. Required check names remain unchanged.
- **Version tags and manual runs:** optimized builds, bundled captions,
  installers, and package smoke checks.

Manual runs can package one platform or all three.
Tags and manual runs always build, including when only documentation changed.

Compiled Rust dependencies, Qt, pip downloads, and Kiwi resources are cached.
The first run or a toolchain change still needs a cold build.

| Target                           | Package                                             |
| -------------------------------- | --------------------------------------------------- |
| Ubuntu 24.04 LTS x86_64          | AppImage                                            |
| Windows Server 2022 x86_64, MSVC | Per-user Inno Setup `.exe` installer                |
| macOS 15 arm64                   | `.dmg` with `Sori.app` and an Applications shortcut |

Packages include SHA-256 checksums. Manual runs upload workflow artifacts.
Version-tag pushes create a draft GitHub release after all three platform jobs
succeed, attaching the packages and checksums. Publishing is manual.

Before tagging, commit the version's release notes in [.github/releases/](../.github/releases/README.md):
tag `v1.0.0` uses `.github/releases/v1.0.0.md` as the release description. Missing or empty
notes fail the tag build. Reruns refresh existing drafts, including their notes
and assets; they refuse to modify published releases.

Test core workflows on clean target systems before advertising a platform as supported.

The Windows installer uses `%LOCALAPPDATA%\Programs\Sori` without administrator
access. It offers shortcuts and an uninstaller that preserves separate user
data. CI checks a silent install, installed tools, and uninstall.
The installer bundles the Vulkan loader required by its mpv DLL and the loader's
license. It does not require a system-wide Vulkan SDK. The installer is unsigned.
macOS CI verifies the DMG and ad-hoc app signature;
Developer ID signing and notarization are not configured.

## Linux AppImage

Prepare the development dependencies, Python with pip/venv, and `appstreamcli`
(`appstream` on Fedora), then run:

```sh
cmake --build build --target package
```

After configuring a Release build, this builds the app, recreates `build/appimage/Sori.AppDir/`, and bundles
Qt/QML/WebEngine, mpv dependencies, FFmpeg/FFprobe, Kiwi, and the private caption
helper. Packaging tools and the AppImage runtime are checksum-pinned and cached
in `build/appimage-tools/`. Review upstream changes before updating failed pins.

An isolated smoke check verifies dependency resolution, helpers, Kiwi resources,
and startup using temporary application data. Outputs are
`build/Sori-<git-version>-x86_64.AppImage` and its checksum.

Users make the downloaded file executable and launch it. If FUSE is unavailable,
set `APPIMAGE_EXTRACT_AND_RUN=1`. Dependencies use private runtime paths;
WebEngine keeps its sandbox and user data stays in the normal Sori data directory.

## Before publishing

- Build for each target OS/architecture. The caption helper is platform-specific;
  keep its complete `helpers/sori-youtube-transcript/` directory in the package.
- Test playback, subtitles, PDFs, analysis, and embeds on clean target systems.
- Check bundled dependency notices and corresponding source obligations.
- Arrange Windows signing and macOS Developer ID signing/notarization as needed.

An AppImage still depends on the host ABI. Use the oldest supported build
baseline and test target distributions. `usr/share/doc/sori/BUILDINFO.json`
records the highest glibc requirement across bundled binaries.

A plain `cmake --install` stages the app and caption helper, but does not perform
the complete native dependency deployment used by these packaging scripts.

The explicit `package` target also selects the DMG or Windows installer on those
platforms. Outputs and staging stay in the selected build directory; normal
builds do not package.
