# Sori

Sori is a local-first Korean immersion app. The Watch page uses Qt Quick for the
sidebar, player controls, and captions. Qt Bridge for Rust exposes
playback and subtitle state to QML. Rust controls libmpv, runs FFprobe and
FFmpeg, and tracks the active subtitle cues. The C++ adapter gives libmpv a Qt
Quick OpenGL framebuffer so the video and UI are composited together.

## Build and run

On Linux, use Qt 6.10 or later with its Quick, OpenGL, and Test modules and
matching private development headers. The icons use Qt Quick Vector Image
and Qt SVG. Use a C++17 toolchain, CMake 3.21 or later,
pkg-config, Rust 1.89 or later, and libmpv development files. CMake uses
the selected Qt SDK's qmake to build Qt Bridge. Use a linker supported by
CXX-Qt such as lld. FFmpeg and FFprobe must be available on PATH to load
subtitle tracks.

From this directory:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
./build/sori
./build/sori "/absolute/path/to/video.mkv"
```

## QML hot reload

With a Qt 6.12 or newer SDK that includes `qmlpreview`, configure a separate
development build. On this machine the local Qt 6.12 SDK is in `build/qt-6.12`.

```sh
cmake -S . -B build/hot -DCMAKE_PREFIX_PATH="$PWD/build/qt-6.12" \
  -DCMAKE_BUILD_TYPE=Release -DSORI_QML_PREVIEW=ON
cmake --build build/hot --target qml-preview
```

Open a video in the preview window. Save an edit to `qml/Main.qml` to see it
in the running app. Simple changes such as colors and sizes can preserve
playback. Structural edits may reload parts of the UI. Rebuild after
changing C++ or Rust. The preview build enables QML debugging and is for
local development.

## Watch controls

Use the sidebar toggle during playback to see the video move with the layout.
**CC** selects primary and secondary tracks. Korean and English tracks are
selected automatically when tagged. **F** enters fullscreen, **Esc**
exits it, **Space** toggles playback, and **Left/Right** seek five seconds.

## Local library

Import UTF-8 text files or paste text in My Library. Open a document to read
it and resume from its saved scroll position. Sori uses the same local SQLite
database as the earlier desktop app, under `com.sori.app/library.sqlite3` in
your user data directory (`$XDG_DATA_HOME` or `~/.local/share` on Linux).

Run `node scripts/setup-kiwi.mjs` once to prepare the pinned Kiwi library and
model. Click a word in Reader to see its morphemes and sentence context. The
analysis runs locally. To distribute a build, place the prepared `kiwi`
directory beside the executable.

Videos opened from a file are added to My Library when the format is supported.
Home and History can resume those videos at their saved position. Attached
UTF-8 SRT and VTT subtitles are saved with the video entry.

Save a word from Reader or click a primary caption in Watch to analyze and
save it. Vocabulary stores the original context and lets you edit meanings,
notes, and tags. You can save words offline with an optional custom meaning.

Select **Look up on Wiktionary** in the analysis panel to fetch Korean-to-English
definitions and save one with the word. Naver opens in your browser.

Settings remembers the appearance mode and the Reader and Watch text renderer
across launches.

## YouTube discovery

Set `SORI_YOUTUBE_API_KEY` in the launch environment or in `.env.local` in the working directory to search the YouTube Data API
from Home and Explore. Paste a YouTube video link in either page without a key.
YouTube videos open in the system browser.

[Inter license](assets/OFL-Inter.txt), [Noto Sans KR license](assets/OFL-NotoSansKR.txt),
and [Lucide license](assets/LUCIDE-LICENSE.txt).
