# Building and developing Sori

To build Sori for yourself, follow [Build from source](#build-from-source).
For code changes, use [Development](#development) and [Testing](#testing).
PR guidance is in [CONTRIBUTING.md](CONTRIBUTING.md).

## Contents

- [Dependencies](#dependencies)
- [Build from source](#build-from-source)
- [Development](#development)
- [Windows development](#windows-development)
- [Testing](#testing)
- [Additional options](#additional-options)

## Dependencies

- Node.js 24+ and npm
- Rust stable and Cargo ([rustup](https://rustup.rs/))
- CMake 3.21+ (only for preparing Kiwi resources)
- Python 3.11+ with venv/pip if you use the optional caption helper
- Git and Bash (PowerShell works on Windows)

FFmpeg and FFprobe are **not** required on PATH: packages bundle static
binaries. Development builds fall back to whatever is on PATH.

## Build from source

```sh
git clone https://github.com/chengggit/sori.git
cd sori
npm ci
cmake -P scripts/setup-kiwi.cmake
npm run native
npm run package
npm run checksums
```

The package target builds the renderer, the release napi addon, and a platform
package in `release/`, then writes `SHA256SUMS.txt`.

- **Linux x86_64:** AppImage. Without FUSE, use `APPIMAGE_EXTRACT_AND_RUN=1`.
- **macOS arm64:** DMG.
- **Windows x86_64:** per-user NSIS installer.

Packages are unsigned; macOS packages are not notarized. For releases see
[RELEASING.md](docs/RELEASING.md).

To build without packaging:

```sh
npm run build
npm run dev
```

## Development

Run from the repository root:

```sh
npm run dev          # builds the debug addon, Vite, and Electron
```

`SORI_DATA_DIR` overrides the library directory. Smoke checks use it so they
never touch your real library. By default Sori uses the same directory the Qt
app used (`GenericDataLocation/com.sori.app`).

UI work happens in `src`: routed screens live in `pages/`, feature
helpers and components in `lib/`, and diagnostics in `dev/`. Electron main and
preload live in `electron/`. Keep renderer desktop calls behind
`src/platform.ts`. The [desktop layout guide](docs/PROJECT_STRUCTURE.md) maps each
module to its owner.

## Windows development

Use PowerShell with Node 24 LTS and a stable Rust toolchain. No Qt SDK, MSVC
mpv build, or Vulkan SDK is required. Prepare Kiwi with
`cmake -P scripts/setup-kiwi.cmake`, then run `npm run dev`.

## Testing

```sh
npm run test:core        # Rust domain tests
npm run test:native      # Kiwi analysis through the addon
npm run test:persistence # CRUD through the bridge on a temp DB
npm run test:migration   # upgrade the old Tauri schema fixture
npm run test:unit        # Vitest helpers
npm run test:electron    # Electron IPC/security regressions (no display)
npm run test:e2e         # Playwright renderer tests
npm run format:check             # Prettier (with Svelte plugin)
```

Playwright needs a browser once: `npx playwright install chromium`.

## Additional options

- `SORI_DATA_DIR=/path/to/dir` — use a different library directory.
- `SORI_ENV_FILE=/path/to/.env.local` — point the YouTube key fallback at a
  specific file.
- `SORI_YOUTUBE_API_KEY=...` — environment fallback when no key is saved.
- `SORI_SMOKE_HASH=<route>` — internal harness for packaged smoke checks.
- Kiwi setup honours `KIWI_DESTINATION` and `SORI_ALLOW_DOWNLOADS`-style
  preparation; see `scripts/setup-kiwi.cmake` for the pinned resources.

Debugging: run `npm run dev`, then use Electron's DevTools from the
window menu or a debugger attached to the main process. Rust changes require
`npm run native` to rebuild the addon.
