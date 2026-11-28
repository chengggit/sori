# Architecture

## Data flow and ownership

```text
Svelte renderer → Platform → preload bridge → Electron main → napi-rs → Rust services → SQLite / Kiwi / local files / HTTP
```

Layer responsibilities are listed in `AGENTS.md`. Additional constraints:

- Every fallible operation uses the `{ ok, data, error }` envelope from
  `bridge.rs`. Mutations and absent lookups may return null data.
- UI calls `src/platform.ts`; it never imports Electron or Node.
  This keeps desktop integration out of components.
- The napi bridge dispatches synchronous core commands with `spawn_blocking` so
  blocking HTTP clients, SQLite, filesystem and media work stay off async workers.
- Async commands are Promises at the bridge boundary; superseded results are
  discarded by the caller where relevant.
- Properties and player controls are lifecycle APIs, not operation results.
- Imported files and local SQLite data remain authoritative.
- Renderer, protocol handlers, and media protocol outlive their views.

## Repository layout

- `electron/main/` owns Electron lifecycle, IPC, protocols and security.
- `electron/preload/index.cjs` exposes the sandboxed bridge.
- `src/` is the Svelte renderer: `pages/` holds routed screens,
  `dev/` holds diagnostics, and `lib/` holds feature helpers/components and shared UI.
- `crates/sori-core/` owns application logic; `crates/sori-node/` is its napi binding.
- Root `scripts/`, `resources/`, `assets/` and `tests/fixtures/` are shared by
  native builds, packaging and integration checks.

This is one npm application plus a Cargo workspace. Electron does not require
Tauri's `src-tauri` shape. Main/preload run as CommonJS; Vite bundles the renderer.
Generated `native/`, `dist/`, and `release/` stay outside source directories.
See the [desktop layout guide](PROJECT_STRUCTURE.md) for individual modules.

## Services and command dispatcher

`crates/sori-core` holds the domain layer copied from the Qt-era `core/` crate
with Qt/mpv adapters removed. `crates/sori-node` exposes `init`,
`initLibrary` and `invoke(command, payload)` through napi-rs.

| Module                               | Responsibility                                             |
| ------------------------------------ | ---------------------------------------------------------- |
| `db.rs`, `schema.sql`                | SQLite initialization and explicit migrations              |
| `library_service.rs`                 | Library state and domain operations; no UI dependency      |
| `documents.rs`, `document_import.rs` | TXT/PDF import validation and storage                      |
| `vocabulary.rs`                      | Saved words, meanings, tags, and source snapshots          |
| `nlp.rs`                             | Dedicated Kiwi thread with UTF-16 token offsets            |
| `reader.rs` (TS port)                | Bounded passage splitting and token grouping               |
| `subtitles.rs` (TS port)             | SRT/VTT parsing; Rust keeps only bounded subprocess output |
| `video_library.rs`                   | Canonical video paths, ffprobe/FFmpeg helpers, checkpoints |
| `youtube.rs` + `youtube/*`           | HTTP orchestration, parsing, settings and local store      |
| `dictionary.rs`, `krdict.rs`         | Wiktionary and KRDict lookup                               |
| `youtube_transcript.rs`              | Optional caption helper orchestration and cache            |

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

## Shared analysis panel

`src/lib/reader/AnalysisPanel.svelte` hosts the tab strip, word heading, dictionary
view and docked save form for Reader and Watch. `src/lib/analysis/state.svelte.ts`
owns superseded-request handling, ordered lemma lookup, KRDict empty-result
fallback, and vocabulary save/edit/remove operations through typed services.
Source word/context and Kiwi UTF-16 offsets remain unchanged.

Inactive dictionary frames are retained for 30 seconds; tab switches preserve
save drafts. Embedded tab order is persisted with keyboard/drag reordering.
HTTPS frames support user-defined lookup templates; third-party response headers
are preserved. Sites can refuse embedding, so Open in browser remains available.
Other resource origins, sandboxing and top-level IPC sender checks stay restricted.

## Explore and discovery

Home and Explore share YouTube VideoCard/VideoGrid, MediaHover and the link
entry dialog. Explore's page only handles presentation and scroll events;
`lib/explore/state.svelte.ts` owns selection, subscription mutations and a
short-lived in-memory view snapshot. Canonical subscriptions/settings stay in
Rust. A snapshot is invalidated after 15 minutes, a configured-key state change,
or a changed channel list for a feed; it is not a persistent results store.

The shared Discovery model owns search/feed request generations, configuration
errors, and deduplicated append-only pagination. Search uses one page cursor;
feeds use per-channel cursors and omit exhausted channels. Repeated response
cursors stop pagination. Disposed models reject late configuration/results.
Explore-origin Watch links carry a return destination so Back restores browsing.

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
- Local resume thumbnails use `sori-thumbnail://video/<id>.jpg`, restricted to
  managed JPEGs under the library thumbnail directory. Rust prepares missing
  metadata/thumbnails through `video:thumbnail`; imported media stays in place.
- FFprobe inspects tracks; FFmpeg extracts text subtitles. Both are bundled in
  packages and fall back to PATH in development.
- `WatchSession` owns source loading, track generations, captions and attached
  text for local and YouTube Watch. Superseded/disposed jobs cannot apply results.
  Caption/transcript passages tokenize lazily through the shared TokenPassage.
- Subtitle generations reject results from previously opened media.
- SRT/VTT attachments save their original text through Rust; reopening restores
  the sidecar. A native TXT picker feeds Rust's existing video/YouTube transcript
  validation and persistence services, including separate text reading progress.
- Caption lookup uses the shared AnalysisModel in a compact popup; full analysis
  uses the shared sidebar. Fullscreen tools remain within the fullscreen element.
- Home/Explore playback links route to Watch. YouTube keeps its IFrame API player,
  while local playback keeps the managed Range protocol. Online metadata loads
  independently of locally stored resume state and cached captions.
- Playback and reading checkpoints are debounced and flushed on leave.
- YouTube uses the embedded IFrame API; Data API calls and caption fetching run
  in Rust. Online features are optional and never required for core workflows.

## Build, packaging, and validation

- npm builds the renderer; Cargo builds the Rust core and napi addon.
- `scripts/setup-kiwi.cmake` prepares pinned Kiwi resources; configuration does
  not download resources.
- electron-builder produces AppImage, per-user NSIS installer, and DMG with the
  app icon, ASAR, unpacked native addon, Kiwi resources and FFmpeg binaries.
- CI targets Ubuntu 24.04 LTS, Windows x86_64, and macOS arm64, uploads packages
  and SHA-256 checksums, and runs Rust/Vitest/Playwright/smoke checks.
- Signing/notarization are separate release steps and are not configured.
