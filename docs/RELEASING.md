# Builds and releases

This guide is for maintainers preparing and publishing Sori releases.

## CI artifacts

[Electron builds](../.github/workflows/build-electron.yml) runs on pushes to
`main`, `electron/**` and `feat/electron-**` branches, version tags, pull
requests, and manual dispatch.

Each platform job installs Node/Rust, prepares Kiwi resources, runs the Rust,
Vitest, Playwright and smoke checks, then builds a package and checksums:

| Target                         | Package                             |
| ------------------------------ | ----------------------------------- |
| Ubuntu 24.04 LTS x86_64        | AppImage                            |
| Windows Server 2022 x86_64     | Per-user NSIS `.exe` installer      |
| macOS 15 arm64                 | `.dmg`                              |

Artifacts include the packages and `SHA256SUMS.txt`. The packages bundle the
app icon, native addon, Kiwi library/models, and static FFmpeg/FFprobe binaries.
Windows builds are unsigned; macOS builds are not notarized.

## Version tags

Version strings come from `package.json` and electron-builder's
`artifactName`. Before tagging, copy
[`.github/releases/ELECTRON-TEMPLATE.md`](../.github/releases/ELECTRON-TEMPLATE.md)
to `.github/releases/<tag>.md` and fill it in. Tag builds attach that file as
the release description. Publishing remains manual.

## Before publishing

- Run the full check suite locally and on all three CI runners.
- Verify a packaged app opens a real library, plays a local MKV, reads a PDF,
  analyzes Korean text and saves vocabulary.
- Check `SHA256SUMS.txt` matches the attached packages.
- Confirm bundled dependency notices (Kiwi, FFmpeg, fonts, icons).
- Arrange Windows signing and macOS Developer ID signing/notarization if the
  release needs them; neither is configured by default.

## Known release limitations

- The optional Python caption helper is not bundled yet; caption fetching needs
  a local Python environment with the helper dependencies.
- macOS packaging is arm64 only.
- The repo keeps the migration history in `MIGRATION.md`; see it for deferred
  items and platform-specific notes.
