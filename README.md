# Sori

Sori is a local-first Korean immersion app. The Watch page uses Qt Quick for the
sidebar, player controls, and captions. Qt Bridge for Rust exposes
playback and subtitle state to QML. Rust controls libmpv, runs FFprobe and
FFmpeg, and tracks the active subtitle cues. The C++ adapter gives libmpv a Qt
Quick OpenGL framebuffer so the video and UI are composited together.

## Prerequisites

The desktop build is currently developed and verified on Linux.

| Dependency | Used for |
| --- | --- |
| Rust 1.89 or later, with Cargo | Core logic and the Qt Bridge |
| C++17 compiler and linker | Qt startup and video rendering adapter |
| CMake 3.21 or later and Make | Configuring and building the app |
| pkg-config and libmpv development files | Finding and linking the native player |
| Qt 6.10 or later | Quick/QML, OpenGL, Test, SVG, and WebEngine Quick |
| Matching Qt private development headers and qmake | Building the Rust/Qt integration |
| FFmpeg and FFprobe on PATH | Inspecting media and extracting subtitle tracks |
| Git | Cloning Sori and fetching its pinned Rust dependencies |
| Bash | Running the optional `scripts/dev` helper |

Use the same Qt SDK for all modules and private headers. The development and
release presets require WebEngine Quick for embedded YouTube playback and
dictionary tabs. Kiwi setup uses CMake to download the native library and model.

### Fedora dependencies

The package names below match the Fedora 44 development environment:

```sh
sudo dnf install git gcc-c++ make cmake pkgconf-pkg-config mpv-devel \
  qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel \
  qt6-qtsvg qt6-qtwebengine-devel ffmpeg-free
```

Install Rust using the official installer. [rustup](https://rustup.rs/)

If rustup is already installed, prepare its stable toolchain with:

```sh
rustup toolchain install stable
rustup default stable
```

On other distributions, install equivalent packages and check that the Qt
version meets the minimum above.

## First-time setup

```sh
git clone https://github.com/chengggit/sori.git
cd sori
cmake -P scripts/setup-kiwi.cmake
./scripts/dev run
```

Kiwi setup downloads pinned Kiwi 0.24.0 binaries and the base language model,
verifies their SHA-256 checksums, and prepares `resources/kiwi/`. Rerunning it
reuses an existing complete installation. Initial setup and dependency downloads
need internet access. Local reading, playback, and Korean analysis then work
offline.

The first build compiles dependencies and takes longer. Subsequent builds reuse
unchanged outputs. Generated builds and Kiwi resources are ignored by Git.

## Daily development

Run commands from the repository root:

| Command | Behavior |
| --- | --- |
| `./scripts/dev build` | Configure and build the development app |
| `./scripts/dev run` | Build and launch the development app |
| `./scripts/dev run "/absolute/path/to/video.mkv"` | Build and launch with a local video |
| `./scripts/dev test` | Configure and run the Rust tests through CTest |
| `./scripts/dev release` | Configure and build the optimized app |

The helper script combines standard CMake commands. The shared configuration is
in `CMakePresets.json`, and you can use it directly:

```sh
cmake --preset dev
cmake --build --preset dev --parallel
./build/development/sori
ctest --preset dev
```

Configure when setting up a checkout or changing build settings. During normal
development, rebuild after editing Rust, C++, or QML, then restart the app to
check the change. QML live preview is described below.

### Development and release builds

| Preset | Output | Rust and C++ configuration |
| --- | --- | --- |
| `dev` | `build/development/sori` | Debug symbols, unoptimized code |
| `release` | `build/sori` | Optimized code |

Separate build directories preserve each mode's compiled outputs. Both use
WebEngine Quick. To build and launch release directly:

```sh
cmake --preset release
cmake --build --preset release --parallel
./build/sori
```

Manual CMake builds map Debug to Cargo's dev profile, RelWithDebInfo to
release-with-debug, and other configurations to release.

CMake discovers Qt through its normal search paths. To select a complete SDK:

```sh
cmake --preset dev -DCMAKE_PREFIX_PATH=/path/to/qt
```

Use `cmake --fresh --preset dev -DCMAKE_PREFIX_PATH=/path/to/qt` when switching
SDKs in an existing build directory with CMake 3.24 or later. This clears cached
configuration so Qt modules can be discovered together.

### Testing changes

`./scripts/dev test` runs the existing Rust tests for persistence, vocabulary,
subtitles, dictionary parsing, and other core behavior. Tests requiring live
services or native Kiwi resources are ignored by default. Use
`ctest --preset dev --verbose` to see individual Rust test results.

For UI changes, also launch the app and exercise the affected workflow. Check
normal and narrow window sizes and both themes. For player changes, check local
playback, subtitle interaction, and fullscreen. Automated Rust tests cover core
behavior; these desktop checks verify the UI.

## Debugging

Build with the development preset, then launch the app under Rust's GDB wrapper:

```sh
rust-gdb --args ./build/development/sori
```

The wrapper loads Rust pretty-printers and can debug Rust and C++ in the same
process. At the GDB prompt, for example:

```text
break main
break sori_qt_register_models
run
print argc
next
continue
backtrace
quit
```

The first breakpoint is C++ startup, and the second is Rust model registration.
Inspect `argc` while stopped in `main`. `next` advances one source line, and
`backtrace` shows the current call stack.

Fedora's headless GDB package exposes the debugger at `/usr/libexec/gdb`.
If you have that package without a `gdb` command on PATH, launch with:

```sh
RUST_GDB=/usr/libexec/gdb rust-gdb --args ./build/development/sori
```

## Optional editor tools

The project uses editor-independent build settings. Configure your preferred
editor's language-server client with the tools you need.

| Language | Tool | Project configuration |
| --- | --- | --- |
| Rust | `rust-analyzer` | Open `core/` or set `linkedProjects` to `core/Cargo.toml` |
| C++ | `clangd` | The root `.clangd` uses `build/development/compile_commands.json` |
| QML | Qt's `qmlls` | Run `qmlls -b build/development --no-cmake-calls` from the repository root |

Configure the development preset before using clangd so the compilation database
exists. Use the selected SDK's `qmlls`. Runtime-registered Rust models currently
lack generated QML type descriptions, so their QML completion is limited.

Rust Analyzer's Cargo process should use the same `QMAKE` as CMake's selected
SDK. For system Qt on Fedora, that can be `/usr/bin/qmake6`. The CMake build and
CTest commands supply their selected qmake automatically.

Optional tool installation on Fedora:

```sh
sudo dnf install gdb clang-tools-extra
rustup component add rust-analyzer rust-src clippy rustfmt
```

## QML live preview

Live preview requires Qt 6.12 or newer with `qmlpreview`. Configure a separate
build using that SDK:

```sh
cmake -S . -B build/hot -DCMAKE_PREFIX_PATH=/path/to/qt-6.12 \
  -DCMAKE_BUILD_TYPE=Debug -DSORI_QML_PREVIEW=ON
cmake --build build/hot --target qml-preview
```

Simple QML edits such as colors and sizes can preserve playback. Structural
edits may reload the UI. Rebuild after changing Rust or C++.

A preview SDK without WebEngine Quick uses browser fallbacks for YouTube and
dictionary tabs. Use the regular development preset to verify embedded content.
The preview build enables QML debugging for local development.

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

Run `cmake -P scripts/setup-kiwi.cmake` once to prepare the pinned Kiwi library and
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
definitions and save one with the word. Reader shows Naver, Papago, and custom
dictionary tabs beside Analysis. In Watch, open them with **Dictionaries**.
Manage tabs in Settings and use `{word}` in a custom HTTPS address to insert
the selected word. Tabs open inside Sori with Qt WebEngine Quick and also
offer an option to open the lookup in a browser.

Settings remembers the appearance mode and the Reader and Watch text renderer
across launches.

## YouTube discovery

Set `SORI_YOUTUBE_API_KEY` in the launch environment or in `.env.local` in the working directory to search the YouTube Data API
from Home and Explore. Paste a YouTube video link in either page without a key.
YouTube playback uses the official embedded player when built with the matching
Qt WebEngine Quick module. If the module is unavailable or a video cannot be
embedded, use **Open in browser**. YouTube progress is saved locally and can
be resumed from Home or History.

[Inter license](assets/OFL-Inter.txt), [Noto Sans KR license](assets/OFL-NotoSansKR.txt),
and [Lucide license](assets/LUCIDE-LICENSE.txt).
