# Sori desktop (Electron scaffold)

This is step 1 of [`MIGRATION.md`](../../MIGRATION.md): the Electron shell only.
It renders a minimal Svelte page and verifies the preload/IPC boundary. Feature
work starts in later steps.

## Commands

Run from the repository root:

```sh
npm install
npm run desktop:dev          # builds the debug addon, then Vite + Electron
npm run desktop:typecheck
npm run desktop:test:core    # cargo test for crates/sori-core
npm run desktop:test:native  # analyze Korean through the built addon
npm run desktop:test:persistence  # CRUD through the bridge on a temp DB
npm run desktop:test:migration    # upgrade a pre-Qt schema fixture
npm run desktop:test:unit
npm run desktop:test:e2e     # needs Playwright Chromium installed
npm run desktop:build        # renderer bundle in apps/desktop/dist
npm run desktop:package      # release addon + platform package
```

`desktop:native` and `desktop:native:release` build the napi-rs addon into
`apps/desktop/native/sori-node.node` (gitignored). `desktop:dev` and
`desktop:package` build it automatically.

The Rust core is a copy of the legacy `core/` crate with Qt/mpv adapters
removed. Wired commands cover analysis, library state, documents, reading
progress, videos, and vocabulary; dictionary/YouTube commands arrive with their
feature steps.

The library database lives in the same directory Qt used
(`GenericDataLocation/com.sori.app`). Set `SORI_DATA_DIR` to use a different
directory — smoke tests do this so they never open a real library.

Open `http://127.0.0.1:5173/#bridge` during development for a bridge page that
exercises `app:ping`, `analyzeText`, and a main-process event. UI logic calls
`platform` (`src/platform.ts`) instead of Electron directly, so a browser
implementation can be added later without touching components.

## Security baseline

- `contextIsolation: true`, `sandbox: true`, `nodeIntegration: false`.
- A narrow `window.sori` preload API with a command allowlist; the renderer
  cannot reach Node or arbitrary IPC channels.
- IPC handlers reject frames other than the app's own page and reject subframes.
- CSP is set by the main process: the dev build allows only the Vite HMR socket;
  the packaged build allows no network origins.
- Navigation and new windows are denied. Dictionary/YouTube origins will be
  added as explicit allowlists when those features land.

The `app:ping` command is a scaffold-only smoke check, not product functionality.

## Smoke check

The main process exits with status 0 after the page loads and mounts when
started with `--smoke`:

```sh
npm run desktop:build
npx electron apps/desktop --smoke
```

A display (or virtual display) is required for this check.
