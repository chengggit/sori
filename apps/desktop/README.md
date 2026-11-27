# Sori desktop (Electron scaffold)

This is step 1 of [`MIGRATION.md`](../../MIGRATION.md): the Electron shell only.
It renders a minimal Svelte page and verifies the preload/IPC boundary. Feature
work starts in later steps.

## Commands

Run from the repository root:

```sh
npm install
npm run desktop:dev          # Vite dev server + Electron window
npm run desktop:typecheck
npm run desktop:test:unit
npm run desktop:test:e2e     # needs Playwright Chromium installed
npm run desktop:build        # renderer bundle in apps/desktop/dist
npm run desktop:package      # platform package in apps/desktop/release
```

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
