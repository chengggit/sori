# Building and developing Sori

To build Sori for yourself, follow [Build from source](#build-from-source).
For code changes, use [Development](#development) and [Testing](#testing).
PR guidance is in [CONTRIBUTING.md](CONTRIBUTING.md).

## Contents

- [Dependencies](#dependencies)
- [Build from source](#build-from-source)
- [Development](#development)
- [Windows development](#windows-development)
- [Testing](#testing)
- [Additional options](#additional-options)

## Dependencies

- Rust stable and Cargo ([rustup](https://rustup.rs/))
- C++17 compiler: GCC/Clang, or MSVC on Windows
- CMake 3.21+ and Make (Ninja for the Windows CI setup)
- Qt 6.10+: Quick/QML, OpenGL, Test, SVG, PDF, WebEngine Quick, private headers, and qmake from the same SDK
- libmpv development files and pkg-config (`MPV_ROOT` on Windows)
- FFmpeg and FFprobe on PATH
- Python 3 with venv/pip support
- Git and Bash

For a Linux AppImage, also install `curl`, `readelf`, and `appstreamcli`.
For a macOS DMG, use Python 3.11+ and Apple's signing/disk-image tools.
Windows packaging needs PowerShell and Inno Setup 6.

Example dependencies install on Fedora 44:

```sh
sudo dnf install git gcc-c++ make cmake pkgconf-pkg-config mpv-devel \
  qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel \
  qt6-qtsvg qt6-qtwebengine-devel qt6-qtpdf-devel ffmpeg-free \
  python3 python3-pip curl binutils appstream
```

For Windows, see [Windows development](#windows-development) below.
The [CI workflow](.github/workflows/build.yml) also shows platform dependency setup.

## Build from source

```sh
git clone https://github.com/chengggit/sori.git
cd sori
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --target package --parallel
```

The package target builds the app first, then creates a package and checksum in
`build/`. The first build needs internet to prepare Kiwi, Rust dependencies, and
the private caption helper; later builds reuse them.

- **Linux x86_64:** make the AppImage executable and run it. Without FUSE, launch with `APPIMAGE_EXTRACT_AND_RUN=1`.
- **macOS Apple Silicon:** open the DMG and drag Sori into Applications.
- **Windows x86_64:** run the installer. Build from an MSVC environment using `-G Ninja -DMPV_ROOT=/path/to/mpv` during configuration, as in CI.

Windows packages are unsigned; macOS packages are not notarized. Linux
compatibility depends on the build host. For public releases, see
[RELEASING.md](docs/RELEASING.md).

To build without packaging, replace the last command with
`cmake --build build --parallel`. Launch `./build/sori` on Linux or
`./build/sori.app/Contents/MacOS/sori` on macOS.

If CMake cannot find Qt, add `-DCMAKE_PREFIX_PATH=/path/to/qt` when configuring.

## Development

From the project root, run:

```sh
./scripts/dev run
```

This builds and launches a Debug app in `build/development/`. Re-run it after
changes, including QML edits. Use `./scripts/dev build` to build without launching.
These helper commands are for Linux/macOS. On Windows, use the commands below.

Debug builds skip caption bundling and don't require Python. To include it:

```sh
cmake --preset dev -DSORI_BUNDLE_TRANSCRIPT_HELPER=ON
./scripts/dev run
```

### Windows development

Install Visual Studio Build Tools with **Desktop development with C++**, Ninja,
and the MSVC x64 Qt SDK. You'll also need an mpv development directory containing
`include/mpv/client.h`, `lib/mpv.lib` (an MSVC import library), and its DLLs in `bin/`.
The mpv build used by CI also needs `vulkan-1.dll`; its setup script supplies the
loader privately.

Open **Developer PowerShell for VS** with the x64 compiler tools enabled. From
Sori's project root, set your actual Qt and mpv paths, then build and launch:

```powershell
$env:QT_ROOT_DIR = "C:/Qt/6.10.2/msvc2022_64"
$env:MPV_ROOT = "C:/deps/mpv"
$env:PATH = "$env:QT_ROOT_DIR/bin;$env:MPV_ROOT/bin;$env:PATH"
$env:RUSTFLAGS = "-Lnative=$env:MPV_ROOT/lib"
cmake -S . -B build/development -G Ninja -DCMAKE_BUILD_TYPE=Debug "-DCMAKE_PREFIX_PATH=$env:QT_ROOT_DIR" "-DMPV_ROOT=$env:MPV_ROOT"
cmake --build build/development --parallel
./build/development/sori.exe
```

For a packaged Release build, use the same environment with `build` instead of
`build/development`, set `-DCMAKE_BUILD_TYPE=Release`, and build `--target package`.
The current Windows installer script expects FFmpeg installed through Chocolatey.

## Testing

```sh
./scripts/dev test
```

On Windows, after building with the commands above, run
`ctest --test-dir build/development --output-on-failure` instead.

This runs Rust, bridge, and QML tests, plus Python tests when its environment is
available. For Rust changes, also run Clippy with your Qt SDK's qmake:

```sh
QMAKE=/path/to/qt/bin/qmake cargo clippy --locked \
  --manifest-path core/Cargo.toml --target-dir build/development/cargo \
  --all-targets -- -D warnings
```

To run UI tests separately, see the [QML test guide](tests/qml/README.md).

## Additional options

<details>
<summary>Offline builds and existing dependencies</summary>

Add these flags to the CMake configuration command as needed:

- `-DSORI_BUNDLE_TRANSCRIPT_HELPER=OFF`: skip caption bundling and build-time Python. Use an unpackaged build; packaging requires the helper.
- `-DSORI_ALLOW_DOWNLOADS=OFF`: require prepared Kiwi/Python resources.
- `-DSORI_KIWI_DIR=/path/to/kiwi -DSORI_PREPARE_KIWI=OFF`: use your existing Kiwi library and models.
- `-DSORI_HELPER_PYTHON=/path/to/python`: use an environment with `scripts/requirements-youtube-build.txt` installed.

Downloads are controlled separately for Cargo: cache its dependencies and set
`CARGO_NET_OFFLINE=true` for offline builds. Generated setup lives in `build/deps/`.

</details>

<details>
<summary>Debugging and editor setup</summary>

- Debug: `rust-gdb --args ./build/development/sori`.
- rust-analyzer: open `core/`; set `QMAKE` to the selected Qt SDK when running Cargo.
- clangd: configure the dev preset first; `.clangd` uses its compilation database.
- QML: run the SDK's `qmlls -b build/development --no-cmake-calls`. Rust model completion is limited.
- When switching Qt SDKs, use `cmake --fresh --preset dev -DCMAKE_PREFIX_PATH=/path/to/qt` (CMake 3.24+).

</details>

<details>
<summary>QML live preview</summary>

Requires Qt 6.12+ with `qmlpreview`:

```sh
cmake -S . -B build/hot -DCMAKE_PREFIX_PATH=/path/to/qt-6.12 \
  -DCMAKE_BUILD_TYPE=Debug -DSORI_QML_PREVIEW=ON
cmake --build build/hot --target qml-preview
```

Structural edits may reload the UI; Rust/C++ edits need rebuilding. Verify embeds
in a regular build if the preview SDK lacks WebEngine.

</details>

<details>
<summary>Native Kiwi and caption-helper checks</summary>

Native Kiwi tests use a separate source-tree fixture. CI runs these through
CTest with `-DSORI_TEST_NATIVE_KIWI=ON`; to run them directly:

```sh
cmake -P scripts/setup-kiwi.cmake
QMAKE=/path/to/qt/bin/qmake cargo test --locked \
  --manifest-path core/Cargo.toml --target-dir build/development/cargo \
  nlp::tests -- --include-ignored
```

After building with caption bundling enabled, check the helper with
`build/development/helpers/sori-youtube-transcript/sori-youtube-transcript --self-test`
(use `.exe` on Windows).

`SORI_PYTHON` selects a development interpreter when no bundled helper is present;
`SORI_TEST_PYTHON` selects the interpreter for Python tests. Native-resource and
live-service tests are skipped by default.

</details>
