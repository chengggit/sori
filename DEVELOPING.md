# Building and developing Sori

Want to build Sori and use it yourself? Install the prerequisites below, then
follow [**Build for your own use**](#build-for-your-own-use). If you'd prefer
an AppImage or DMG, continue to [Build a package](#build-a-package).
The later development sections are for working on the code. For contribution guidance, see
[CONTRIBUTING.md](CONTRIBUTING.md).

## Prerequisites

- Rust stable and Cargo ([rustup](https://rustup.rs/))
- C++17 compiler (GCC/Clang, or MSVC on Windows)
- CMake 3.21+ and Make or Ninja
- Qt 6.10+: Quick/QML, OpenGL, Test, SVG, PDF, WebEngine Quick, matching private headers, and qmake
- libmpv development files and pkg-config (`MPV_ROOT` on Windows)
- FFmpeg and FFprobe on PATH
- Python 3 with venv/pip support (unless caption bundling is disabled)
- Git and Bash

Fedora 44 packages:

```sh
sudo dnf install git gcc-c++ make cmake pkgconf-pkg-config mpv-devel \
  qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel \
  qt6-qtsvg qt6-qtwebengine-devel qt6-qtpdf-devel ffmpeg-free python3 python3-pip
```

Use one matching Qt SDK. For other platforms, see the dependency setup in
[CI](.github/workflows/build.yml); Windows builds use MSVC.

## Build for your own use

After installing the prerequisites above, run:

```sh
git clone https://github.com/chengggit/sori.git
cd sori
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
```

CMake prepares checksum-verified Kiwi resources and a private caption-helper
Python environment under `build/deps/` during the build. It never installs system
packages or changes your global Python environment. Initial setup needs internet;
subsequent builds reuse prepared resources. The packaged caption helper includes
its own Python runtime.

Launch on Linux with `./build/sori`, or on macOS with
`./build/sori.app/Contents/MacOS/sori`. Use the same command for later launches.
Keep the checkout and build folder in place; this build uses your installed
system dependencies. You don't need to create an installer or run the test
suites just to use the app.

If Qt isn't found automatically, add `-DCMAKE_PREFIX_PATH=/path/to/qt` to the
configuration command.

Optional configuration flags:

| Flag                                                    | Purpose                                                                                             |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `-DSORI_BUNDLE_TRANSCRIPT_HELPER=OFF`                   | Build without bundling captions; no build-time Python required                                      |
| `-DSORI_ALLOW_DOWNLOADS=OFF`                            | Reject missing Kiwi/Python setup instead of downloading                                             |
| `-DSORI_KIWI_DIR=/path/to/kiwi -DSORI_PREPARE_KIWI=OFF` | Use existing native library and models                                                              |
| `-DSORI_HELPER_PYTHON=/path/to/python`                  | Use an existing environment containing the requirements in `scripts/requirements-youtube-build.txt` |

`SORI_ALLOW_DOWNLOADS` controls our resource setup, not Cargo. For fully offline
builds, also cache Rust dependencies and set `CARGO_NET_OFFLINE=true`.
To update Python dependencies offline, supply a prepared helper environment.

For Windows source builds, follow the MSVC/Ninja setup in the
[CI workflow](.github/workflows/build.yml); these Make-based presets are for
Unix systems.

## Build a package

After configuring a Release build as above, run:

```sh
cmake --build build --target package
```

This builds Sori and creates an AppImage (Linux x86_64), DMG (macOS Apple Silicon),
or installer (Windows x86_64) in your selected build directory, with a checksum.
Packaging requires caption bundling to be enabled.

Additional packaging tools:

- Linux: `curl`, `readelf`, and `appstreamcli` (`appstream` on Fedora/Ubuntu).
- macOS: Python 3.11+ and the standard signing/disk-image tools.
- Windows: PowerShell, Inno Setup 6, and the media-tool setup used in CI.

On Linux, make the AppImage executable to launch it; without FUSE, use
`APPIMAGE_EXTRACT_AND_RUN=1`. On macOS, open the DMG and drag Sori into Applications.
Windows installers are unsigned; macOS packages are ad-hoc signed, not notarized.
Linux compatibility depends on the build system's ABI.

For CI artifacts and public release preparation, see
[docs/RELEASING.md](docs/RELEASING.md).

## Working on the code

After cloning, use the development build for faster
iteration and debugging:

```sh
./scripts/dev run
```

The Debug preset leaves caption bundling off. To enable it, configure with
`-DSORI_BUNDLE_TRANSCRIPT_HELPER=ON`; the build prepares its private environment.

To select a Qt SDK for development, use
`cmake --preset dev -DCMAKE_PREFIX_PATH=/path/to/qt`. When running Cargo directly,
set `QMAKE` to the same SDK's qmake that CMake uses.

## Dev commands

Run these from the repository root:

| Command                  | Purpose                                                       |
| ------------------------ | ------------------------------------------------------------- |
| `./scripts/dev build`    | Build the development app                                     |
| `./scripts/dev run`      | Build and launch it                                           |
| `./scripts/dev test`     | Build the bridge test and run the registered test suites      |
| `./scripts/dev release`  | Build the optimized app and transcript helper                 |
| `./scripts/dev appimage` | Package a Linux x86_64 AppImage; also requires `appstreamcli` |

Development output is under `build/development/`; release output is under
`build/`. Rebuild and restart after code changes, including embedded QML.
The existing ignore rules keep build outputs, local environments, and Kiwi resources out of Git.

For CI artifacts and distribution packages, see [docs/RELEASING.md](docs/RELEASING.md).

To use CMake directly:

```sh
cmake --preset dev
cmake --build --preset dev --parallel
./build/development/sori
cmake --build --preset dev --target sori-bridge-test
ctest --preset dev
```

When switching Qt SDKs, use `cmake --fresh --preset dev
-DCMAKE_PREFIX_PATH=/path/to/qt` (CMake 3.24+) to clear cached SDK paths.

## Tests

For code changes, please run `./scripts/dev test` before opening your PR. CTest covers Rust, the native Qt
bridge, and QML regressions; Python helper tests run when its environment is
available. See [tests/qml/README.md](tests/qml/README.md) for direct QML commands.

For Rust changes, please check Clippy too, using your selected Qt SDK:

```sh
QMAKE=/path/to/qt/bin/qmake cargo clippy --locked \
  --manifest-path core/Cargo.toml --target-dir build/development/cargo \
  --all-targets -- -D warnings
```

Live-service and native-resource tests are skipped by default. If you're changing NLP behavior, you can run the offline Kiwi tests after resource setup:

```sh
QMAKE=/path/to/qt/bin/qmake cargo test --locked \
  --manifest-path core/Cargo.toml --target-dir build/development/cargo \
  nlp::tests -- --include-ignored
```

Please use temporary data for tests to keep your own library safe. For UI
changes, try both themes, a narrow window, and application zoom. If you change
the player, a quick check of playback, subtitles, and fullscreen helps too.

If you can't run a check on your setup, just mention it in the PR so we know
what still needs a look.

## Debugging and editor tools

Launch a development build with `rust-gdb --args ./build/development/sori`
to debug Rust and C++ together. Useful breakpoints are `main` and
`sori_qt_register_models`. If Fedora only provides `/usr/libexec/gdb`, set
`RUST_GDB=/usr/libexec/gdb` when launching the wrapper.

| Tool          | Configuration                                                                             |
| ------------- | ----------------------------------------------------------------------------------------- |
| rust-analyzer | Open `core/` or set `linkedProjects` to `core/Cargo.toml`; use the selected SDK's `QMAKE` |
| clangd        | Configure first; `.clangd` uses `build/development/compile_commands.json`                 |
| qmlls         | Run the selected SDK's `qmlls -b build/development --no-cmake-calls`                      |

Runtime-registered Rust models currently have limited QML completion.

## QML live preview

With Qt 6.12+ and `qmlpreview`, use a separate build:

```sh
cmake -S . -B build/hot -DCMAKE_PREFIX_PATH=/path/to/qt-6.12 \
  -DCMAKE_BUILD_TYPE=Debug -DSORI_QML_PREVIEW=ON
cmake --build build/hot --target qml-preview
```

Simple visual edits can preserve playback; structural edits may reload the UI.
Rust/C++ changes still need a rebuild. Preview enables local QML debugging.
If the preview SDK lacks WebEngine, verify embeds in the regular build.

## Transcript helper troubleshooting

Sori prefers the bundled helper, then falls back to `.venv-youtube` in development.
An existing development environment can be prepared with `python3 -m venv
.venv-youtube` followed by `.venv-youtube/bin/python -m pip install -r
scripts/requirements-youtube-build.txt`.
`SORI_PYTHON` selects a development interpreter; the CMake setting
`SORI_HELPER_PYTHON` selects the interpreter used to package it.
`SORI_TEST_PYTHON` selects the environment for CTest's Python suite.

To check the bundled helper locally:

```sh
cmake --preset dev -DSORI_BUNDLE_TRANSCRIPT_HELPER=ON
cmake --build --preset dev
build/development/helpers/sori-youtube-transcript/sori-youtube-transcript --self-test
```

On Windows, use the helper's `.exe` filename. Offline helper tests can also run
with `.venv-youtube/bin/python -m unittest discover -s tests/python`.
