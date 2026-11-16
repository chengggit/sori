# Sori

Sori is a local-first Korean immersion app. The current Qt implementation is
a standalone Watch prototype. It uses Qt Quick for the sidebar, player controls,
captions, and transcript. Qt Bridge for Rust exposes playback and subtitle state
to QML. Rust controls libmpv, runs FFprobe and FFmpeg, and tracks the active
subtitle cues. The C++ adapter gives libmpv a Qt Quick OpenGL framebuffer so
the video and UI are composited together.

## Build and run

On Linux, use Qt 6.10 or later with its Quick, OpenGL, and Test modules and
matching private development headers, a C++17 toolchain, CMake 3.21 or later,
pkg-config, Rust 1.88 or later, and libmpv development files. Qt Bridge needs
the Qt SDK's qmake on PATH (or set `QMAKE`). Use a linker supported by
CXX-Qt such as lld. FFmpeg and FFprobe must be available on PATH to load
subtitle tracks.

From this directory:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
./build/sori-qt-player
./build/sori-qt-player "/absolute/path/to/video.mkv"
```

Use the sidebar toggle during playback to see the video move with the layout.
**CC** selects primary and secondary tracks. Korean and English tracks are
selected automatically when tagged. Scroll the transcript to suspend
**Follow playback**, or click a cue to seek. **F** enters fullscreen, **Esc**
exits it, **Space** toggles playback, and **Left/Right** seek five seconds.

This is a one-page prototype. Library integration and Kiwi lookup are outside
this build, and the navigation labels are visual references to the Svelte app.

[Inter license](assets/OFL-Inter.txt) and [Noto Sans KR license](assets/OFL-NotoSansKR.txt).
