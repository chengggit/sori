# Architecture

## Data flow and ownership

```text
QML → Qt Bridge → Rust models → domain services → SQLite / local files / Kiwi
C++ Qt Quick framebuffer adapter ↔ Rust-controlled libmpv
Optional online features → Rust HTTP clients / isolated Python transcript helper
```

Layer responsibilities are listed in `AGENTS.md`. Additional constraints:

- Run long filesystem, network, analysis, and media jobs outside the Qt UI thread.
- Tag completions with request IDs or generations; discard superseded results.
- Imported files and local SQLite data remain authoritative.
- `RenderHost` outlives the QML engine; mpv outlives its renderers.
- Render on the owning thread with a current OpenGL context.

## Services and bridge

| Module                                | Responsibility                                             |
| ------------------------------------- | ---------------------------------------------------------- |
| `library_model.rs`                    | Qt properties, signals, and job dispatch                   |
| `library_service.rs`                  | Library state and domain operations; no QObject dependency |
| `library_jobs.rs`                     | Background metadata/thumbnail I/O and retry tracking       |
| `youtube_model.rs`                    | YouTube Qt adapter                                         |
| `youtube.rs`                          | YouTube HTTP orchestration                                 |
| `youtube/{settings,store,parsing}.rs` | Settings, SQLite persistence, and response parsing         |

Fallible Library, Analysis, and YouTube operations use `Response<T>` from
`bridge.rs`; services retain `Result<T, String>` internally:

```json
{ "ok": true, "data": null, "error": "" }
```

- Success: typed `data`, empty `error`. Mutations and absent lookups may return null.
- Failure: `ok: false`, null `data`, and a visible error message.
- QML and mocks consume the same envelope directly.
- Async calls return a scalar request ID; completion signals carry the envelope.
- Properties and player controls remain state/lifecycle APIs.
- Background enrichment returns an acknowledgement, then reports through
  `backgroundFinished`. Failures also update library error state.

Playback saves update the affected cache entry. Collection notifications still
serialize whole collections; introduce row-level models only if measurements justify it.

## Persistence

- Database: `library.sqlite3` under `com.sori.app` in the generic user data directory.
- Each operation owns its connection, enables foreign keys, and uses a five-second busy timeout.
- `schema.sql` covers media, progress, vocabulary/meanings/tags, transcripts,
  YouTube subscriptions/history, and settings.
- Saved words retain source title, context, and meaning snapshots after source removal.
- Videos stay at their original paths; PDFs are copied into managed `pdfs/` storage.
  Thumbnails are derived data.
- Pre-release schema version is 1, with explicit compatibility handling. Add
  versioned migrations before supporting arbitrary distributed upgrades.
- Never silently reset a library. Coordinate database and file cleanup on import failure.
- Tests must use temporary libraries, never the user's database.

## Reading and analysis

| Constraint     | Behavior                                                                |
| -------------- | ----------------------------------------------------------------------- |
| TXT import     | UTF-8, at most 2 MiB                                                    |
| PDF import     | At most 50 MiB; page-only storage                                       |
| PDF display    | QtPdf book/scroll views; clickable words require an embedded text layer |
| Scanned PDFs   | Readable without clickable text; no OCR requirement                     |
| Word caches    | Scoped to one document                                                  |
| Analysis input | At most 16 KiB; reject null characters                                  |
| Source offsets | UTF-16 units, matching QML/JavaScript                                   |

`nlp.rs` lazily loads pinned local Kiwi resources once on a dedicated owning
thread. Its bounded queue avoids sharing the native handle across threads.
`reader.rs` extracts bounded selection context.

Reader and both Watch pages reuse analysis/vocabulary components. Dictionary
behavior is defined in `PRODUCT.md`. Visited embeds survive sidebar closure for
30 seconds; reopening cancels expiry. Destroying views may leave WebEngine's
shared process/cache memory allocated.

## Media and progress

- Rust controls libmpv; C++ composites its framebuffer into Qt Quick.
- Register videos by canonical path. FFprobe inspects tracks; FFmpeg extracts
  text subtitles and thumbnails.
- Subtitle generations reject results from previously opened media.
- Support SRT/VTT attachments and optional untimed TXT transcripts.
- Playback checkpoints update history. Debounce reader/transcript scroll saves
  and flush on leaving; finish restoration before saving a new position.
- Keep filesystem, persistence, and playback errors visible.

YouTube uses the official embedded player via Qt WebEngine Quick. The optional
Python caption helper returns bounded JSON and runs with a deadline. Release
builds bundle its private runtime; local workflows do not require Python.

## Build, packaging, and validation

- CMake builds C++, invokes locked Cargo dependencies, and embeds QML/resources.
  `CMakePresets.json` defines dev/release builds. Build-time targets prepare Kiwi
  and an optional private caption environment under the build directory; configuration
  does not download resources. Existing resources and offline setup are supported.
- Use one matching Qt SDK for all Qt modules and the Rust bridge.
- CI targets Ubuntu 24.04 LTS, Windows x86_64, and macOS arm64.
- Artifacts: Linux AppImage, per-user Windows Inno Setup installer, and macOS
  DMG with an Applications shortcut. Windows signing and Apple Developer ID
  signing/notarization are separate release steps.
- AppImages bundle private dependencies, but the build host's ABI still limits
  compatibility. Validate on clean target systems before public release.

See [DEVELOPING.md](../DEVELOPING.md) for commands,
[RELEASING.md](RELEASING.md) for packaging, and
[the QML test guide](../tests/qml/README.md) for component tests.

- Keep Rust domain/service tests independent of Qt UI instantiation.
- The native `bridge` suite checks real model envelopes and async completions
  against a temporary library.
- QML regressions exercise real components with mocked services.
- Mark live-service and native-resource tests explicitly.
- Check changed UI flows in both themes and at narrow widths.
- Run strict Clippy for Rust changes.
