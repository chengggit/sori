# Architecture

## Data flow and ownership

```text
Svelte renderer → Platform → preload bridge → Electron main → napi-rs → Rust services → SQLite / Kiwi / local files / HTTP
```

Layer responsibilities are listed in `AGENTS.md`. Additional constraints:

- Every fallible operation uses the `{ ok, data, error }` envelope from
  `bridge.rs`. Mutations and absent lookups may return null data.
- UI calls `apps/desktop/src/platform.ts`; it never imports Electron or Node.
  The web implementation can replace this seam without touching components.
- Async commands are Promises at the bridge boundary; superseded results are
  discarded by the caller where relevant.
- Properties and player controls are lifecycle APIs, not operation results.
- Imported files and local SQLite data remain authoritative.
- Renderer, protocol handlers, and media protocol outlive their views.

## Services and command dispatcher

`crates/sori-core` holds the domain layer copied from the Qt-era `core/` crate
with Qt/mpv adapters removed. `crates/sori-node` exposes `init`,
`initLibrary` and `invoke(command, payload)` through napi-rs.

| Module                                | Responsibility                                             |
| ------------------------------------- | ---------------------------------------------------------- |
| `db.rs`, `schema.sql`                 | SQLite initialization and explicit migrations              |
| `library_service.rs`                  | Library state and domain operations; no UI dependency      |
| `documents.rs`, `document_import.rs`  | TXT/PDF import validation and storage                      |
| `vocabulary.rs`                       | Saved words, meanings, tags, and source snapshots           |
| `nlp.rs`                              | Dedicated Kiwi thread with UTF-16 token offsets             |
| `reader.rs` (TS port)                 | Bounded passage splitting and token grouping                |
| `subtitles.rs` (TS port)              | SRT/VTT parsing; Rust keeps only bounded subprocess output  |
| `video_library.rs`                    | Canonical video paths, ffprobe/FFmpeg helpers, checkpoints  |
| `youtube.rs` + `youtube/*`            | HTTP orchestration, parsing, settings and local store       |
| `dictionary.rs`, `krdict.rs`          | Wiktionary and KRDict lookup                                |
| `youtube_transcript.rs`               | Optional caption helper orchestration and cache             |

## Persistence

- Database: `library.sqlite3` under `GenericDataLocation/com.sori.app`, matching
  the Qt app. `SORI_DATA_DIR` overrides it for tests.
- Each operation owns a connection, enables foreign keys, and uses a five-second
  busy timeout.
- `schema.sql` covers media, progress, vocabulary/meanings/tags, transcripts,
  YouTube subscriptions/history, and settings.
- Missing pre-release columns (`pdf_path`, `duration`, `thumbnail`) are added
  explicitly; new tables are created with `IF NOT EXISTS`.
- Saved words retain source title, context, and meaning snapshots after source
  removal. Videos stay at their original paths; PDFs are copied into managed
  `pdfs/` storage.
- Tests use temporary libraries, never the user's database.

## Reading and analysis

- TXT import: UTF-8, at most 2 MiB; paste-as-text is stored as a TXT document.
- PDF import: at most 50 MiB; page-only storage in `pdfs/`.
- PDF display uses pdf.js in Book and Scroll views. Clickable words require an
  embedded text layer; scanned PDFs still render.
- Analysis input is bounded to 16 KiB and rejects null characters.
- Source offsets are UTF-16 code units, matching JavaScript `slice()`.
- Kiwi is loaded lazily on a dedicated owning thread using pinned local models.

## Media and progress

- Chromium `<video>` plays local media through the privileged `sori-media://`
  Range protocol; there is no mpv or native player addon.
- FFprobe inspects tracks; FFmpeg extracts text subtitles. Both are bundled in
  packages and fall back to PATH in development.
- Subtitle generations reject results from previously opened media.
- SRT/VTT attachments and untimed TXT transcripts are supported.
- Playback and reading checkpoints are debounced and flushed on leave.
- YouTube uses the embedded IFrame API; Data API calls and caption fetching run
  in Rust. Online features are optional and never required for core workflows.

## Build, packaging, and validation

- npm workspaces build the renderer; Cargo builds the Rust core and napi addon.
- `scripts/setup-kiwi.cmake` prepares pinned Kiwi resources; configuration does
  not download resources.
- electron-builder produces AppImage, per-user NSIS installer, and DMG with the
  app icon, ASAR, unpacked native addon, Kiwi resources and FFmpeg binaries.
- CI targets Ubuntu 24.04 LTS, Windows x86_64, and macOS arm64, uploads packages
  and SHA-256 checksums, and runs Rust/Vitest/Playwright/smoke checks.
- Signing/notarization are separate release steps and are not configured.
