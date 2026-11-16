# Sori

Sori is a local-first Korean immersion app. The Watch page uses Qt Quick for the
sidebar, player controls, captions, and transcript. Qt Bridge for Rust exposes
playback and subtitle state to QML. Rust controls libmpv, runs FFprobe and
FFmpeg, and tracks the active subtitle cues. The C++ adapter gives libmpv a Qt
Quick OpenGL framebuffer so the video and UI are composited together.

## Build and run

On Linux, use Qt 6.10 or later with its Quick, OpenGL, and Test modules and
matching private development headers, a C++17 toolchain, CMake 3.21 or later,
pkg-config, Rust 1.88 or later, and libmpv development files. CMake uses
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
selected automatically when tagged. Scroll the transcript to suspend
**Follow playback**, or click a cue to seek. **F** enters fullscreen, **Esc**
exits it, **Space** toggles playback, and **Left/Right** seek five seconds.

Watch is the current page. Library integration and Kiwi lookup are planned.

[Inter license](assets/OFL-Inter.txt) and [Noto Sans KR license](assets/OFL-NotoSansKR.txt).
