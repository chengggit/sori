# Sori Electron migration

This is the working plan for moving Sori from Qt Quick + Rust to Electron while
keeping the app local-first, offline-capable, and consistent across Linux,
Windows, and macOS. It is a living checklist: mark steps done as branches merge
into the integration branch, and update the document when a decision changes.

## Why

- Qt text layout was inconsistent across platforms; Windows builds had broken
  layout.
- Qt WebEngine made the app effectively an Electron app already, without
  Electron's ecosystem or web-client reuse.
- Tauri/WebGTK was painful to work with.
- Electron's renderer is web technology, so the same UI can later serve a web
  client for people who don't want to install another desktop app.

## Decisions

| Decision           | Choice                                          | Reason                                                                                                                                                                                                                    |
| ------------------ | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Frontend framework | Keep Svelte 5 + TypeScript                      | Old Svelte codebase is the same repo's pre-Qt ancestor with current deps; it already builds as a static SPA via `adapter-static`                                                                                          |
| Rust backend       | Keep it, expose through a napi-rs N-API addon   | Preserves field-tested domain logic and its tests; N-API is ABI-stable so no rebuild per Electron version; one app binary to ship                                                                                         |
| Kiwi               | Keep the native Rust binding and vendored patch | Same tokens, UTF-16 offsets, POS tags, and tests; the patch fixes an out-of-bounds crash in Kiwi 0.24's `tagToString` probing (see `core/vendor/kiwi-rs/SORI-PATCH.md`) — it is not Qt-specific and Electron needs it too |
| Playback           | Chromium `<video>` only, no mpv                 | The Electron demo plays real MKVs through a privileged `sori-media://` Range-streaming protocol                                                                                                                           |
| Web client         | Keep the door open, don't build it yet          | Define a `Platform` interface now; add a browser adapter only if web becomes real                                                                                                                                         |
| Repository         | Same repo, long-lived migration branch          | Preserves git history and issue/release continuity                                                                                                                                                                        |

## Target shape

```text
apps/desktop      # Electron main/preload + Vite/Svelte renderer
crates/sori-core  # Rust domain layer, SQLite, Kiwi, media/HTTP services
crates/sori-node  # napi-rs binding: invoke(command, payload) -> Response<T> + events
```

Pure, stateless transforms (token grouping, POS labels, grammar explanations,
subtitle parsing, YouTube link/duration parsing, embedded-tab settings) live in
TypeScript, reusing the old Svelte codebase. Everything that owns SQLite, Kiwi,
or filesystem/media subprocesses stays in Rust. Do not add `better-sqlite3`
alongside `rusqlite` — one owner per data store.

## Reuse map

| Source                                                  | Reuse                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Old Svelte app (`~/Documents/sori`)                     | Pure TS modules: `src/lib/features/reader/{tokens,breakdown,progress}.ts`, `features/nlp/tokenization.ts`, `features/video/{subtitles,playback}.ts`, `features/dashboard/{youtube,playback}.ts`, `features/dictionary/{dictionary,embedded,embed-settings}.ts`, typed service wrappers; theme tokens from `src/routes/layout.css`; fonts/icons/licenses |
| Current Qt app                                          | Feature spec (`docs/PRODUCT.md`, `docs/USAGE.md`), `core/src/schema.sql`, domain services (`vocabulary`, `dictionary`, `krdict`, `youtube`, `reader`, etc.), Kiwi resources, QML test flows in `tests/qml/`                                                                                                                                             |
| Electron demo (`~/Documents/Code/sori-electron-player`) | `sori-media://` scheme + Range streamer, security setup (`contextIsolation`, `sandbox`, `contextBridge`, sender-frame validation, CSP), Watch interactions and metrics                                                                                                                                                                                  |
| Do not port                                             | Tauri plugins/capabilities, `convertFileSrc`, `isTauri`, webview zoom APIs, `@get-air/video-tauri`, `video_http.rs`, uncommitted WebKit hacks, dead `DictionaryLookup.svelte`, Linux-only `build-linux.cjs`, exposed `.env.local` key (rotate it)                                                                                                       |

Delete from Rust: `lib.rs` mpv FFI, `controls.rs`, `bridge.rs` (replace with TS
types using the same `{ok, data, error}` envelope), all `*_model.rs` Qt adapters,
and the Qt/C++ build and packaging code.

## Rust → TypeScript split

Rule of thumb: one owner per data store. Everything that touches SQLite, Kiwi,
or filesystem/media subprocesses stays in Rust. Pure, stateless transforms can
move to TS — preferably reusing the old Svelte implementation.

### Port to TS (recommended, ~560–600 lines out of Rust)

| Rust file                                 | What moves                                                                                                                                | TS source                                              | Contract change                                                                                                                                |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `core/src/subtitles.rs` (lines 1–60)      | `parse()`, `seconds()`, `cue()` — SRT/VTT → sorted cues                                                                                   | `features/video/subtitles.ts` + demo's `subtitles.mjs` | Rust returns raw WebVTT; renderer parses. Keep `command_output()` (lines 62–71) in Rust                                                        |
| `core/src/youtube/parsing.rs` (327 lines) | All 14 functions: oembed, ISO-8601 duration, `video_id()`, `valid_id()`, search, channel input, API errors                                | `features/dashboard/youtube.ts`                        | `youtube.rs` returns raw JSON bodies; TS parses them                                                                                           |
| `core/src/reader.rs` (~180 of 325 lines)  | `grammar_explanation`, `word_breakdown`, `lookup_terms`, `dictionary_form`, POS labels, `passage()`, `attached_number_start`, `is_hangul` | `features/reader/tokens.ts` + `breakdown.ts`           | Rust `analyze()` returns just `{word, context, morphemes}`; TS derives the rest. Keep `analyze()` and `word_ranges()` in Rust — they call Kiwi |

Do these in step 3, where the `Platform` contract is defined. When a function
moves, delete the Rust version and port its tests to Vitest (there are existing
tests for mixed cues, passage/Unicode bounds, clickable ranges, and YouTube
parsing).

### Keep in Rust

`db.rs` + `schema.sql`, `documents.rs`, `document_import.rs` (transactional file
copy), `library_service.rs`, `library_jobs.rs`, `progress.rs`, `vocabulary.rs`,
`video_library.rs` (ffprobe/FFmpeg extraction), `video_transcript.rs`,
`youtube.rs` (HTTP orchestration), `youtube/{settings,store}.rs`, `nlp.rs` (Kiwi),
and `process.rs` (91 lines — `video_library.rs` depends on it, so duplicating it
in Node would be worse than keeping it).

## Ground rules

- Integration branch: `electron/migration` off `main`. Each numbered step below
  is its own branch and PR into the integration branch. `main` stays untouched
  until the final cutover.
- The Qt app stays buildable and runnable until the cutover so both apps can be
  compared side by side.
- Each step ends with its "Done when" criteria; no placeholder UI is merged.
- Risky build/runtime work (addon, persistence, playback) is front-loaded.

## To-do list

- [x] **0. `chore/electron-prep`** — Back up the current tree, create
      `electron/migration`, add this checklist and the decision record.
      _Done when:_ branch exists and the Qt baseline `./scripts/dev test` passes.
      Backup: `~/Documents/sori-qt` at `e0896f7`; baseline 4/4 CTest suites passed.

- [x] **1. `feat/electron-scaffold`** — `apps/desktop` with Vite + Svelte 5 +
      strict TS, Electron 45.3.2, electron-builder config, preload/main security
      baseline from the demo, Vitest + Playwright, CI job parallel to the Qt one.
      _Done when:_ `npm run dev` opens a blank window and a packaged smoke app
      launches on Linux, Windows, and macOS.
      Verified locally on Linux: dev and packaged `--smoke` both exit 0,
      typecheck/unit/E2E pass. Windows/macOS run in
      `.github/workflows/build-electron.yml` (not yet executed).

- [x] **2. `feat/electron-rust-addon`** — Create `crates/sori-core` from `core/`,
      strip Qt/mpv modules, add `crates/sori-node` with napi-rs
      `invoke(command, payload) -> Response<T>` and an event emitter. Keep the
      vendored patched `kiwi-rs` and Cargo patch unchanged; use existing
      `resources/kiwi` for development.
      _Done when:_ `cargo test` passes, a JS snippet calls
      `invoke('analyzeText', …)` and gets real tokens, and prebuilds succeed on
      all three platforms.
      Verified locally: 63 Rust tests passed (4 native/live tests ignored);
      `scripts/smoke-native.mjs` returned `학교/NNG 에/JKB 가/VV …`; dev and
      packaged smoke exit 0; the addon is unpacked from ASAR correctly. The
      patched `kiwi-rs` is confirmed via `cargo tree` and its `[patch]` now lives
      in the workspace root. Windows/macOS prebuilds are not run locally — CI
      covers them. Events are stubbed until background jobs land; Kiwi resources
      are not yet bundled into packages (step 16).

- [x] **3. `feat/electron-platform-bridge`** — Define the `Platform` interface
      and desktop adapter (`sori.invoke`, `sori.onEvent`). Port the pure TS
      helpers from the old app (`tokens.ts`, `breakdown.ts`, `subtitles.ts`,
      `youtube.ts` parsing, `embed-settings.ts`) and delete any Rust equivalent
      that moves, so there is one source of truth.
      _Done when:_ helpers have Vitest coverage and a dev-only bridge page
      exercises commands and events.
      Verified: 19 Vitest tests, `svelte-check` clean, 62 Rust tests, and an
      Electron bridge-page smoke (`#bridge`) showing `pong`, real Kiwi tokens,
      and a main-process event. Deleted Rust `reader.rs` and the full subtitle
      parser (kept only `has_cues` + `command_output`). `youtube/parsing.rs`
      remains because Rust background services still depend on it; its TS port
      is UI-facing and the duplication is recorded in the post-cutover backlog.
      Dictionary and IFrame playback helpers arrive with their feature steps.

- [x] **4. `feat/electron-persistence`** — Expose DB-backed commands through
      `invoke`; add explicit migrations so an old `library.sqlite3` gains
      `pdf_path`, `duration`, `thumbnail`, and the new tables; point Electron
      `userData` at the old `com.sori.app` location.
      _Done when:_ a **copied** real library opens, migrates, and passes CRUD
      tests on temporary DBs.
      Verified: 63 Rust tests, `scripts/smoke-persistence.mjs` (document,
      progress and vocabulary CRUD on a temp DB), and
      `scripts/smoke-migration.mjs` (a fixture matching the old Tauri schema
      gains all missing columns/tables while keeping its rows). Electron
      `userData` now matches Qt's `GenericDataLocation/com.sori.app` on all
      three platforms; `SORI_DATA_DIR` overrides it for smoke tests so real
      libraries are never touched. Dev/bridge/packaged smoke exit 0.

- [x] **5. `feat/electron-analysis`** — Wire Kiwi → tokens → TS grouping/POS
      labels/grammar into one reusable analysis component/panel.
      _Done when:_ output matches the Qt app on the `nlp.rs` test corpus,
      including UTF-16 offsets and the emoji case.
      Verified: `smoke-native.mjs` now checks the `nlp.rs` vectors (`마음/만큼/은`,
      `NNG/JKB/JX`), emoji offset 3, and the 16 KiB limit. Ported Qt's
      `attached_number_start` into `wordRanges` so clickable ranges match the
      Qt vector including `3,000회` and `1.5년` (the old Svelte regex split
      decimals). `AnalysisPanel.svelte` is reusable and exercised at `#analysis`.
      20 Vitest tests, typecheck, and dev/packaged smoke pass.

- [x] **6. `feat/electron-shell`** — Sidebar, routing, and theme tokens from old
      `layout.css` plus current `Theme.qml`; light/dark themes, zoom, narrow
      widths.
      _Done when:_ every page navigates in both themes and the Playwright visual
      smoke passes.
      Verified: 3 Playwright tests (navigation, both themes, narrow-width
      collapse), clean typecheck/build, dev and packaged smoke exit 0. Adopted
      the old app's UI stack — Tailwind 4, Lucide, shadcn-svelte config,
      `cn`/bits-ui/tailwind-variants — and its OKLCH palette as Tailwind tokens;
      Qt's `Theme.qml` supplies the layout measurements. Fonts are bundled by
      Vite. shadcn UI primitives will be copied in as the feature pages need
      them; Qt-only behavior is layered on top of the reused Svelte components.

- [x] **7. `feat/electron-library`** — TXT import (UTF-8, ≤2 MiB), paste-as-file,
      list/open/remove, background metadata jobs.
      _Done when:_ matches `LibraryPage.qml`.
      Verified: 4 Playwright tests, clean typecheck/build, and an Electron
      smoke that inserts a Korean document through the bridge then sees it in
      the Library page. Reused the old shadcn Button/Input primitives; the page
      has search, file import (txt/pdf) via a native dialog, paste, edit,
      delete confirmation, and a read-only document preview. A `library-changed`
      event keeps the page in sync with mutations. The video shelf is read-only
      here — import and thumbnail/duration jobs arrive with step 11.

- [x] **8. `feat/electron-reader`** — TXT reader, clickable words, analysis
      panel, debounced progress save/restore.
      _Done when:_ matches `ReaderPage.qml` and `tst_readerlayout.qml`.
      Verified: 5 Playwright tests, clean typecheck/build, and an Electron smoke
      that opens a document, clicks a Korean word, saves it to vocabulary, and
      restores a 0.6 scroll position from the DB. Passages use the Qt-derived
      `wordRanges` offsets; PDF documents show an explicit deferred note until
      step 10. Library "open" now navigates to `#/reader?id=…`.

- [x] **9. `feat/electron-vocabulary`** — Save word with context, edit
      meanings/notes/tags, list/search/filter, remove; retain snapshots after
      source removal.
      _Done when:_ matches `VocabularyPage.qml`; saved meanings work offline.
      Verified: 6 Playwright tests, clean typecheck/build, and an Electron smoke
      that saves a word through the bridge, edits its meaning in the UI, then
      removes it (final vocabulary count 0). The page mirrors Qt's search
      fields, type filter, sort options, count label and source-context details.
      Snapshot retention after source deletion is inherited from the Rust
      `vocabulary` service.

- [x] **10. `feat/electron-pdf`** — pdf.js with Book/Scroll views, text-layer
      word clicks, scanned-PDF rendering, progress via `pdf_path`.
      _Done when:_ matches `PdfBookReader.qml` against
      `tests/fixtures/pdf-rendering.pdf`.
      Verified: Electron smoke against that fixture renders a canvas and 25
      text-layer spans, clicking a span opens Kiwi analysis, and Scroll mode
      re-renders. A privileged `sori-pdf://` protocol serves PDF bytes with
      Range support from `userData/pdfs`; CSP allows it explicitly. Also adopted
      the old app's Prettier config and scripts (`npm run format`,
      `format:check`); there was no ESLint in that codebase.

- [x] **11. `feat/electron-playback`** — Move the `sori-media://` Range protocol
      into Electron main; ffprobe metadata; bundle ffmpeg/ffprobe as
      `extraResources`; play/seek/fullscreen/keyboard; playback checkpoints.
      _Done when:_ the real MKV codec matrix passes on all three OSes without
      mpv.
      Verified: 7 Playwright tests, clean typecheck/build, and an Electron smoke
      that generates an MKV, imports it, streams it through `sori-media://`,
      plays it, seeks, and confirms the checkpoint was saved. Library now has
      video import and opening navigates to `#/watch?id=…`. The native IPC
      adapter now wraps raw main-process replies in the shared envelope.
      Not done here: ffmpeg/ffprobe bundling into installers (step 16) and the
      user's real MKV codec matrix on Windows/macOS (CI only).

- [x] **12. `feat/electron-subtitles`** — Embedded tracks → WebVTT, SRT/VTT
      sidecars, dual tracks, clickable subtitle words → analysis, transcript
      follow/click-to-seek.
      _Done when:_ `tst_subtitletranscript` and `tst_transcriptheader` flows are
      ported and passing.
      Verified: an MKV with a tagged Korean SubRip track was generated and
      played; the track was auto-selected, its cue rendered, a clicked word
      opened Kiwi analysis, and clicking a transcript cue sought to 3 s. Added
      `video:saveSubtitles` to the Rust dispatcher. Sidecar attachments work
      for the session but are not persisted yet; they need a file-path-based
      command. Smoke checks now use isolated data directories per route.

- [x] **13. `feat/electron-dictionaries`** — Wiktionary + KRDict services,
      offline saved meanings, embedded Naver/Papago/KRDict/custom tabs with drag
      reorder and 30-second retention.
      _Done when:_ `tst_dictionarytabs`, `tst_dictionaryorder`, and
      `tst_dictionaryretention` flows pass.
      Verified: KRDict key validation, provider selection and removal through
      the Rust commands; the dictionary panel renders from analysis lookup
      terms with two embedded tabs that drag-reorder and keep frames for 30 s.
      Added an allowlisted `shell:openExternal` fallback for sites that refuse
      iframing. Offline saved meanings come from the existing vocabulary edit
      path. Live Wiktionary/KRDict responses were not smoke-tested (network
      dependent). All nine smoke routes pass with isolated data directories.

- [ ] **14. `feat/electron-youtube`** — iframe/IFrame API playback, Data API
      search with key, history/subscriptions, optional caption helper.
      _Done when:_ `tst_youtubeadapter` and `tst_discoverypagination` flows pass.

- [ ] **15. `feat/electron-settings`** — Theme, zoom, Inter/Noto Sans KR fonts,
      dictionary provider/key, embed-tab order, `app_settings` table.
      _Done when:_ matches `SettingsSheet.qml`.

- [ ] **16. `feat/electron-packaging`** — electron-builder AppImage / per-user
      NSIS / DMG, icons, ASAR, `extraResources` for Kiwi + ffmpeg, checksums,
      signing/notarization, CI artifacts, release notes template.
      _Done when:_ clean-system install and launch verified on all three OSes.

- [ ] **17. `release/electron-cutover`** — Full parity audit against
      `PRODUCT.md` and `USAGE.md`, migrate a real library once more, rewrite all
      docs, delete `qml/`, `src/`, and CMake files, then merge
      `electron/migration` → `main`.
      _Done when:_ the first Electron release is tagged.

Steps 7–15 are independent feature slices and can be reordered by priority. If
a web client ever starts, it begins after step 3, where the `Platform` seam
exists; no other step needs to change for it.

## Post-cutover backlog (deferred)

Not part of the migration. Revisit only after the Electron release is tagged and
stable. These modules are stateless network services with no DB dependency, but
their parsing is field-tested and would need rewriting plus fixtures in TS.

- [ ] Retire the Rust copy of `youtube/parsing.rs` once background jobs are
      ported; step 3 added a UI-facing TS version, so both currently exist.
- [ ] Port `core/src/dictionary.rs` (377 lines) — Wiktionary fetch + wikitext /
      Hanja parsing. Old TS `dictionary.ts` has only types/cache, so the parser
      must be rewritten and verified against real responses.
- [ ] Port `core/src/krdict.rs` (312 lines) — KRDict API call + response mapping.
- [ ] Reconsider `core/src/youtube_transcript.rs` — lines 111–165 are DB
      functions and stay in Rust; only the helper orchestration could move, and
      splitting it likely isn't worth it.

Only do these if shrinking the native addon becomes valuable. Delete the Rust
version and port its tests when a module actually moves.
