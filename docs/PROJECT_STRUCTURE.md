# Sori desktop

Electron hosts a Vite/Svelte renderer and a Rust core exposed through napi-rs.
Run all commands from the repository root; see [DEVELOPING.md](../DEVELOPING.md)
for prerequisites and the full check suite.

```sh
npm ci
npm run dev          # debug addon + Vite + Electron
npm run typecheck
npm run test:unit
npm run test:electron
npm run test:e2e     # requires Playwright Chromium
npm run build       # renderer only
npm run package     # release addon + renderer + platform package
```

## Layout

```text
electron/
  main/
    index.cjs       # application lifecycle, schemes, window creation
    runtime.cjs     # library location, native addon, bundled tool paths
    ipc.cjs         # native dialogs and command handlers
    media.cjs       # local media/PDF protocols and exposed video records
    security.cjs    # CSP and IPC sender validation
  preload/
    index.cjs       # sandboxed contextBridge API and channel allowlists
src/
  main.ts           # renderer entry point
  App.svelte        # routing, theme and app composition
  platform.ts       # renderer's only desktop integration seam
  bridge.ts         # bridge types (no runtime Electron import)
  envelope.ts       # shared operation result helpers
  pages/            # routed product screens
  dev/              # bridge and analysis diagnostic screens
  lib/
    components/     # shared shell and UI primitives
    reader/         # reading helpers, shared panel host and PDF reader
    analysis/       # dictionary requests, vocabulary state and save editor
    dictionary/     # lookup helpers, settings and dictionary panel
    library/        # command wrappers, refresh/thumbnail state and media cards
    video/          # playback, subtitles and command wrappers
    dashboard/      # YouTube parsing and IFrame playback helpers
    home/           # Home search, discovery requests and resume helpers
    youtube/        # typed YouTube command wrappers
native/             # generated sori-node.node (ignored)
dist/               # generated renderer bundle (ignored)
release/            # generated installers and checksums (ignored)
tests/
  electron/         # main-process regression tests without a display
  e2e/              # Playwright renderer tests
  smoke/            # real Electron checks, loaded only with --smoke
```

Keep components close to the feature that owns them; use `lib/components` for
shared UI. Components call `platform` or typed command wrappers. Electron main
owns native integration; Rust owns SQLite, Kiwi and application services.
The Rust workspace lives in `crates/`, preparation scripts in `scripts/`,
and package resources in `resources/` and `assets/` at the repository root.

Main and preload use CommonJS directly, so no separate Electron compilation
step is needed. Vite builds only the renderer. Runtime paths use
`app.getAppPath()` or `process.resourcesPath` so module moves do not change
resource resolution. The preload stays self-contained for Electron's sandbox.

`electron-builder.yml` includes `electron/`, the renderer, the generated addon
and the smoke harness. The addon is unpacked from ASAR; Kiwi and FFmpeg/FFprobe
are bundled as extra resources. Smoke checks stay available in packages to
validate the actual installed resource paths.

## Data and diagnostics

The library remains at Qt's `GenericDataLocation/com.sori.app` location.
`SORI_DATA_DIR` selects another library. Always use a temporary directory when
running smoke checks; feature smoke routes create and edit sample data.

With Vite running, launch Electron with `--smoke` for a mount check.
`SORI_SMOKE_HASH` selects a feature check: `home`, `bridge`, `analysis`, `library`,
`reader`, `vocabulary`, `pdf`, `watch`, `subtitles`, `dictionary`, `youtube`, or
`settings`. For example, on Linux/macOS:

```sh
SORI_DATA_DIR="$(mktemp -d)" SORI_SMOKE_HASH=reader npx electron . --smoke
```

Open `#bridge` or `#analysis` in the development app for interactive diagnostics.
These screens are in `src/dev`; they are not library features.

## Security boundary

Windows use context isolation, sandboxing and disabled Node integration. Preload
exposes only allowlisted IPC channels. Main validates the sending top-level
frame and denies navigation/new windows. CSP restricts scripts and connections
to app/YouTube origins while allowing HTTPS frames for user-defined dictionary
templates. Embedded pages keep their own response security policies; they have
no Node or preload access. See [ARCHITECTURE.md](ARCHITECTURE.md)
for data flow and ownership.
