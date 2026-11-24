# Architecture

Sori is a local-first desktop application built with Qt Quick and Rust. Core
reading, local video playback, Korean analysis, vocabulary, and persistence work
without an account, AI service, or remote server.

## Boundaries and data flow

```text
QML presentation and interaction
        ↓ Qt Bridge slots / properties / signals
Rust application models → domain modules → SQLite / local files / Kiwi
        ↓
libmpv playback ← C++ Qt Quick framebuffer adapter

Optional online features: Rust HTTP clients / isolated Python transcript helper
```

- **QML (`qml/`)** owns layout, navigation, input, and UI state. Reuse components
  and theme tokens. Keep persistence, provider validation, and media processing
  in Rust.
- **C++ (`src/`)** starts Qt, selects the OpenGL backend, hosts the mpv renderer,
  and provides access to QtPdf text geometry. `RenderHost` outlives the QML
  engine; mpv outlives all renderers. Render functions require the owning thread
  and a current OpenGL context.
- **Rust (`core/src/`)** owns media handling, persistence, Korean analysis, and
  optional online integrations. Qt-facing models adapt domain results into QML
  properties, request IDs, and completion signals.
- **Python (`scripts/youtube_transcript.py`)** is an optional isolated helper
  for existing YouTube captions. It is not required for local learning workflows.

Long-running filesystem, network, analysis, and media work should run outside
the Qt UI thread. Background completions carry request IDs or generations so
superseded results cannot replace current UI state. Imported content and local
SQLite data remain authoritative.

## Persistence

`db.rs` initializes `library.sqlite3` under `com.sori.app` in the platform's generic
user data directory. Operations own their connection, enable foreign keys, and
use a five-second busy timeout. Never open a user's real library in tests.

`schema.sql` defines documents, videos, reading/watch progress, vocabulary,
meanings/tags, transcripts, YouTube subscriptions/history, and settings. Saved
vocabulary retains a snapshot of its source title, context, and selected meaning
when its source is removed. Large video files stay at their original locations;
PDFs are copied into the managed `pdfs/` directory. Thumbnails are derived data.

During pre-release development the schema remains at version 1, with explicit
compatibility handling for earlier development databases. Introduce versioned
migrations before distributed releases require arbitrary schema upgrades. Do not
silently reset a library. Coordinate database changes with filesystem cleanup
when an import fails.

## Reading and Korean analysis

UTF-8 TXT imports are limited to 2 MiB. PDFs are limited to 50 MiB and stored as
page-only documents. QtPdf renders them in book or continuous-scroll mode;
clickable words come from the embedded text layer. Scans without a text layer
remain readable but have no clickable words. Word caches belong to one document.

`nlp.rs` lazily loads pinned local Kiwi resources on a dedicated owning thread.
Its bounded queue avoids sharing the native handle across threads. Requests are
limited to 16 KiB and reject null characters. `reader.rs` extracts bounded context
around a selection. Source spans use UTF-16 offsets to match QML/JavaScript.

Reader, local Watch, and YouTube Watch share analysis and vocabulary components.
Morphological analysis is independent of online dictionary access. Wiktionary
and KRDict return plain-text definitions; provider attribution and selected
meanings are retained with saved vocabulary for offline access.

## Watching

Rust controls libmpv while the C++ adapter composites its output into Qt Quick.
Local videos are registered by canonical path. FFprobe inspects tracks and
FFmpeg extracts text subtitles and thumbnails. Subtitle state uses generations
to reject results from previously opened media. SRT/VTT attachments and optional
untimed TXT transcripts are stored with the video.

Progress checkpoints update local history. Reader and transcript scroll saves
are debounced and flushed on leaving. Restoration must finish before saving a
new position. Filesystem, persistence, and player errors must remain visible.

YouTube uses the official embedded player through optional Qt WebEngine Quick.
Search and subscribed-channel discovery require an optional YouTube Data API
key; pasted video links do not. Embedded playback reports checkpoints to the
shared transcript view. The optional Python helper returns bounded JSON and
runs with a deadline. Release builds bundle a private helper runtime; native Qt,
mpv, Kiwi, and platform installer deployment remain separate packaging steps.

## Build and validation

CMake builds the C++ executable, invokes locked Cargo dependencies, and bundles
QML/resources. `CMakePresets.json` defines development and release configurations.
Use one matching Qt SDK for every Qt module and the Rust bridge.

See `README.md` and `tests/qml/README.md` for setup and test commands. Keep pure
Rust domain tests independent of Qt UI instantiation. QML regressions should
exercise the actual affected components with mocked services; live service and
native-resource tests must be clearly marked. Check changed desktop flows in
both themes and at narrow window sizes. Run strict Clippy for Rust changes.

Cloud synchronization, accounts, and optional AI processing are outside the MVP
and must not become dependencies of the local experience.
