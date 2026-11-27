# Sori Electron release (TEMPLATE)

Copy this file to `.github/releases/<version>.md` and fill it in before tagging
an Electron release. The existing release workflow attaches the file matching
the tag as the release description.

## What's included

- Local reading, watching, Korean analysis and vocabulary, all offline.
- Embedded dictionaries and optional YouTube features.

## Platform notes

- Linux AppImage, Windows per-user installer, and macOS DMG.
- Windows builds are unsigned; macOS builds are not notarized.
- Packages bundle Kiwi resources and FFmpeg/FFprobe; verify SHA256SUMS.txt.

## Known limitations

- List anything deferred from MIGRATION.md (for example the Python caption
  helper bundling) before publishing.
