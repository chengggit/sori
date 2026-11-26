# Building and developing Sori

Want to build Sori and use it yourself? Install the prerequisites below, then
follow [**Build for your own use**](#build-for-your-own-use). If you'd prefer
an AppImage or DMG, continue to [Build a package](#build-a-package).
The later development sections are for working on the code. For contribution guidance, see
[CONTRIBUTING.md](CONTRIBUTING.md).

## Prerequisites

| Dependency                            | Notes                                                          |
| ------------------------------------- | -------------------------------------------------------------- |
| Rust stable and Cargo                 | Core logic and Qt Bridge                                       |
| C++17 compiler                        | GCC/Clang on Linux/macOS; MSVC on Windows                      |
| CMake 3.21+ and a build tool          | The local presets use Make; CI uses Ninja                      |
| Qt 6.10+                              | Quick/QML, OpenGL, Test, SVG, PDF, and WebEngine Quick         |
| Matching Qt private headers and qmake | Use one complete SDK for C++ and Rust                          |
| libmpv development files              | Found through pkg-config on Linux/macOS; `MPV_ROOT` on Windows |
| FFmpeg and FFprobe on PATH            | Media inspection, subtitles, and thumbnails                    |
| Git and Bash                          | Dependencies and the `scripts/dev` helper                      |

Most local development and testing has been on Fedora 44. The
[CI workflow](.github/workflows/build.yml) also shows the Ubuntu 24.04, Windows,
and macOS setup, though the Windows/macOS jobs still need their first hosted
runs. For Windows, use MSVC rather than MinGW.

Example dependencies install on Fedora 44:

```sh
sudo dnf install git gcc-c++ make cmake pkgconf-pkg-config mpv-devel \
  qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel \
  qt6-qtsvg qt6-qtwebengine-devel qt6-qtpdf-devel ffmpeg-free
```

Install Rust through [rustup](https://rustup.rs/). Other distributions may need a
separate Qt SDK if their packaged Qt version is below the minimum.

## Build for your own use

After installing the prerequisites and Python 3 with pip/venv support, run:

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

| Flag | Purpose |
| ---- | ------- |
| `-DSORI_BUNDLE_TRANSCRIPT_HELPER=OFF` | Build without bundling captions; no build-time Python required |
| `-DSORI_ALLOW_DOWNLOADS=OFF` | Reject missing Kiwi/Python setup instead of downloading |
| `-DSORI_KIWI_DIR=/path/to/kiwi -DSORI_PREPARE_KIWI=OFF` | Use existing native library and models |
| `-DSORI_HELPER_PYTHON=/path/to/python` | Use an existing environment containing the requirements in `scripts/requirements-youtube-build.txt` |

`SORI_ALLOW_DOWNLOADS` controls our resource setup, not Cargo. For fully offline
builds, also cache Rust dependencies and set `CARGO_NET_OFFLINE=true`.
To update Python dependencies offline, supply a prepared helper environment.

For Windows source builds, follow the MSVC/Ninja setup in the
[CI workflow](.github/workflows/build.yml); these Make-based presets are for
Unix systems.

## Build a package

Want a packaged app for yourself? After completing the source build above, use
the matching command below on the target OS. You don't need the maintainer
release checklist for a personal package.

### Linux AppImage (x86_64)

Install `appstreamcli` (`appstream` on Fedora/Ubuntu), then run:

```sh
./scripts/dev appimage
```

The AppImage and checksum appear in `build/`. Make the `.AppImage` executable
and launch it. If FUSE is unavailable, use `APPIMAGE_EXTRACT_AND_RUN=1`.
Compatibility still depends on your build system's Linux ABI.

### macOS DMG (Apple Silicon)

The current packaging script targets arm64. Use Python 3.11+ and set
`QT_ROOT_DIR` to the same Qt SDK used for your source build:

```sh
QT_ROOT_DIR=/path/to/qt bash scripts/ci/package-macos.sh
```

The DMG and checksum appear in `build/`. Open the DMG and drag Sori into
Applications. This package is ad-hoc signed and isn't notarized, so macOS may
require approval to open it. macOS packaging still awaits its first hosted CI run.

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

| Command                                  | Purpose                                                       |
| ---------------------------------------- | ------------------------------------------------------------- |
| `./scripts/dev build`                    | Build the development app                                     |
| `./scripts/dev run`                      | Build and launch it                                           |
| `./scripts/dev run "/path/to/video.mkv"` | Launch with a local video                                     |
| `./scripts/dev test`                     | Build the bridge test and run the registered test suites      |
| `./scripts/dev release`                  | Build the optimized app and transcript helper                 |
| `./scripts/dev appimage`                 | Package a Linux x86_64 AppImage; also requires `appstreamcli` |

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

| Tool | Configuration |
| ---- | ------------- |
| rust-analyzer | Open `core/` or set `linkedProjects` to `core/Cargo.toml`; use the selected SDK's `QMAKE` |
| clangd | Configure first; `.clangd` uses `build/development/compile_commands.json` |
| qmlls | Run the selected SDK's `qmlls -b build/development --no-cmake-calls` |

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
