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

| Decision | Choice | Reason |
| --- | --- | --- |
| Frontend framework | Keep Svelte 5 + TypeScript | Old Svelte codebase is the same repo's pre-Qt ancestor with current deps; it already builds as a static SPA via `adapter-static` |
| Rust backend | Keep it, expose through a napi-rs N-API addon | Preserves field-tested domain logic and its tests; N-API is ABI-stable so no rebuild per Electron version; one app binary to ship |
| Kiwi | Keep the native Rust binding and vendored patch | Same tokens, UTF-16 offsets, POS tags, and tests; the patch fixes an out-of-bounds crash in Kiwi 0.24's `tagToString` probing (see `core/vendor/kiwi-rs/SORI-PATCH.md`) — it is not Qt-specific and Electron needs it too |
| Playback | Chromium `<video>` only, no mpv | The Electron demo plays real MKVs through a privileged `sori-media://` Range-streaming protocol |
| Web client | Keep the door open, don't build it yet | Define a `Platform` interface now; add a browser adapter only if web becomes real |
| Repository | Same repo, long-lived migration branch | Preserves git history and issue/release continuity |

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

| Source | Reuse |
| --- | --- |
| Old Svelte app (`~/Documents/sori`) | Pure TS modules: `src/lib/features/reader/{tokens,breakdown,progress}.ts`, `features/nlp/tokenization.ts`, `features/video/{subtitles,playback}.ts`, `features/dashboard/{youtube,playback}.ts`, `features/dictionary/{dictionary,embedded,embed-settings}.ts`, typed service wrappers; theme tokens from `src/routes/layout.css`; fonts/icons/licenses |
| Current Qt app | Feature spec (`docs/PRODUCT.md`, `docs/USAGE.md`), `core/src/schema.sql`, domain services (`vocabulary`, `dictionary`, `krdict`, `youtube`, `reader`, etc.), Kiwi resources, QML test flows in `tests/qml/` |
| Electron demo (`~/Documents/Code/sori-electron-player`) | `sori-media://` scheme + Range streamer, security setup (`contextIsolation`, `sandbox`, `contextBridge`, sender-frame validation, CSP), Watch interactions and metrics |
| Do not port | Tauri plugins/capabilities, `convertFileSrc`, `isTauri`, webview zoom APIs, `@get-air/video-tauri`, `video_http.rs`, uncommitted WebKit hacks, dead `DictionaryLookup.svelte`, Linux-only `build-linux.cjs`, exposed `.env.local` key (rotate it) |

Delete from Rust: `lib.rs` mpv FFI, `controls.rs`, `bridge.rs` (replace with TS
types using the same `{ok, data, error}` envelope), all `*_model.rs` Qt adapters,
and the Qt/C++ build and packaging code.

## Rust → TypeScript split

Rule of thumb: one owner per data store. Everything that touches SQLite, Kiwi,
or filesystem/media subprocesses stays in Rust. Pure, stateless transforms can
move to TS — preferably reusing the old Svelte implementation.

### Port to TS (recommended, ~560–600 lines out of Rust)

| Rust file | What moves | TS source | Contract change |
| --- | --- | --- | --- |
| `core/src/subtitles.rs` (lines 1–60) | `parse()`, `seconds()`, `cue()` — SRT/VTT → sorted cues | `features/video/subtitles.ts` + demo's `subtitles.mjs` | Rust returns raw WebVTT; renderer parses. Keep `command_output()` (lines 62–71) in Rust |
| `core/src/youtube/parsing.rs` (327 lines) | All 14 functions: oembed, ISO-8601 duration, `video_id()`, `valid_id()`, search, channel input, API errors | `features/dashboard/youtube.ts` | `youtube.rs` returns raw JSON bodies; TS parses them |
| `core/src/reader.rs` (~180 of 325 lines) | `grammar_explanation`, `word_breakdown`, `lookup_terms`, `dictionary_form`, POS labels, `passage()`, `attached_number_start`, `is_hangul` | `features/reader/tokens.ts` + `breakdown.ts` | Rust `analyze()` returns just `{word, context, morphemes}`; TS derives the rest. Keep `analyze()` and `word_ranges()` in Rust — they call Kiwi |

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

- [ ] **0. `chore/electron-prep`** — Back up the current tree, create
      `electron/migration`, add this checklist and the decision record.
      *Done when:* branch exists and the Qt baseline `./scripts/dev test` passes.

- [ ] **1. `feat/electron-scaffold`** — `apps/desktop` with Vite + Svelte 5 +
      strict TS, Electron 45.3.2, electron-builder config, preload/main security
      baseline from the demo, Vitest + Playwright, CI job parallel to the Qt one.
      *Done when:* `npm run dev` opens a blank window and a packaged smoke app
      launches on Linux, Windows, and macOS.

- [ ] **2. `feat/electron-rust-addon`** — Create `crates/sori-core` from `core/`,
      strip Qt/mpv modules, add `crates/sori-node` with napi-rs
      `invoke(command, payload) -> Response<T>` and an event emitter. Keep the
      vendored patched `kiwi-rs` and Cargo patch unchanged; use existing
      `resources/kiwi` for development.
      *Done when:* `cargo test` passes, a JS snippet calls
      `invoke('analyzeText', …)` and gets real tokens, and prebuilds succeed on
      all three platforms.

- [ ] **3. `feat/electron-platform-bridge`** — Define the `Platform` interface
      and desktop adapter (`sori.invoke`, `sori.onEvent`). Port the pure TS
      helpers from the old app (`tokens.ts`, `breakdown.ts`, `subtitles.ts`,
      `youtube.ts` parsing, `embed-settings.ts`) and delete any Rust equivalent
      that moves, so there is one source of truth.
      *Done when:* helpers have Vitest coverage and a dev-only bridge page
      exercises commands and events.

- [ ] **4. `feat/electron-persistence`** — Expose DB-backed commands through
      `invoke`; add explicit migrations so an old `library.sqlite3` gains
      `pdf_path`, `duration`, `thumbnail`, and the new tables; point Electron
      `userData` at the old `com.sori.app` location.
      *Done when:* a **copied** real library opens, migrates, and passes CRUD
      tests on temporary DBs.

- [ ] **5. `feat/electron-analysis`** — Wire Kiwi → tokens → TS grouping/POS
      labels/grammar into one reusable analysis component/panel.
      *Done when:* output matches the Qt app on the `nlp.rs` test corpus,
      including UTF-16 offsets and the emoji case.

- [ ] **6. `feat/electron-shell`** — Sidebar, routing, and theme tokens from old
      `layout.css` plus current `Theme.qml`; light/dark themes, zoom, narrow
      widths.
      *Done when:* every page navigates in both themes and the Playwright visual
      smoke passes.

- [ ] **7. `feat/electron-library`** — TXT import (UTF-8, ≤2 MiB), paste-as-file,
      list/open/remove, background metadata jobs.
      *Done when:* matches `LibraryPage.qml`.

- [ ] **8. `feat/electron-reader`** — TXT reader, clickable words, analysis
      panel, debounced progress save/restore.
      *Done when:* matches `ReaderPage.qml` and `tst_readerlayout.qml`.

- [ ] **9. `feat/electron-vocabulary`** — Save word with context, edit
      meanings/notes/tags, list/search/filter, remove; retain snapshots after
      source removal.
      *Done when:* matches `VocabularyPage.qml`; saved meanings work offline.

- [ ] **10. `feat/electron-pdf`** — pdf.js with Book/Scroll views, text-layer
      word clicks, scanned-PDF rendering, progress via `pdf_path`.
      *Done when:* matches `PdfBookReader.qml` against
      `tests/fixtures/pdf-rendering.pdf`.

- [ ] **11. `feat/electron-playback`** — Move the `sori-media://` Range protocol
      into Electron main; ffprobe metadata; bundle ffmpeg/ffprobe as
      `extraResources`; play/seek/fullscreen/keyboard; playback checkpoints.
      *Done when:* the real MKV codec matrix passes on all three OSes without
      mpv.

- [ ] **12. `feat/electron-subtitles`** — Embedded tracks → WebVTT, SRT/VTT
      sidecars, dual tracks, clickable subtitle words → analysis, transcript
      follow/click-to-seek.
      *Done when:* `tst_subtitletranscript` and `tst_transcriptheader` flows are
      ported and passing.

- [ ] **13. `feat/electron-dictionaries`** — Wiktionary + KRDict services,
      offline saved meanings, embedded Naver/Papago/KRDict/custom tabs with drag
      reorder and 30-second retention.
      *Done when:* `tst_dictionarytabs`, `tst_dictionaryorder`, and
      `tst_dictionaryretention` flows pass.

- [ ] **14. `feat/electron-youtube`** — iframe/IFrame API playback, Data API
      search with key, history/subscriptions, optional caption helper.
      *Done when:* `tst_youtubeadapter` and `tst_discoverypagination` flows pass.

- [ ] **15. `feat/electron-settings`** — Theme, zoom, Inter/Noto Sans KR fonts,
      dictionary provider/key, embed-tab order, `app_settings` table.
      *Done when:* matches `SettingsSheet.qml`.

- [ ] **16. `feat/electron-packaging`** — electron-builder AppImage / per-user
      NSIS / DMG, icons, ASAR, `extraResources` for Kiwi + ffmpeg, checksums,
      signing/notarization, CI artifacts, release notes template.
      *Done when:* clean-system install and launch verified on all three OSes.

- [ ] **17. `release/electron-cutover`** — Full parity audit against
      `PRODUCT.md` and `USAGE.md`, migrate a real library once more, rewrite all
      docs, delete `qml/`, `src/`, and CMake files, then merge
      `electron/migration` → `main`.
      *Done when:* the first Electron release is tagged.

Steps 7–15 are independent feature slices and can be reordered by priority. If
a web client ever starts, it begins after step 3, where the `Platform` seam
exists; no other step needs to change for it.

## Post-cutover backlog (deferred)

Not part of the migration. Revisit only after the Electron release is tagged and
stable. These modules are stateless network services with no DB dependency, but
their parsing is field-tested and would need rewriting plus fixtures in TS.

- [ ] Port `core/src/dictionary.rs` (377 lines) — Wiktionary fetch + wikitext /
      Hanja parsing. Old TS `dictionary.ts` has only types/cache, so the parser
      must be rewritten and verified against real responses.
- [ ] Port `core/src/krdict.rs` (312 lines) — KRDict API call + response mapping.
- [ ] Reconsider `core/src/youtube_transcript.rs` — lines 111–165 are DB
      functions and stay in Rust; only the helper orchestration could move, and
      splitting it likely isn't worth it.

Only do these if shrinking the native addon becomes valuable. Delete the Rust
version and port its tests when a module actually moves.
