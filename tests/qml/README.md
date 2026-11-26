# QML UI tests

These tests check Sori's interface using real QML components and fake backend
services. They run offline without opening your library or playing real videos.

## Run the UI tests

Install the dependencies in [DEVELOPING.md](../../DEVELOPING.md), then run these
commands from the repository root:

```sh
cmake --preset dev
ctest --preset dev -R '^qml$' --output-on-failure
```

This runs only the QML tests. You don't need to build the app first.
If Qt isn't found, add `-DCMAKE_PREFIX_PATH=/path/to/qt` to the first command.

On Windows, use your configured development build instead of the Unix preset:

```powershell
ctest --test-dir build/development -R '^qml$' --output-on-failure
```

To run all test suites on Linux/macOS, use `./scripts/dev test`.

## Run one test file

Use `qmltestrunner` from the same Qt SDK as your build. For example, on
Linux/macOS:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic \
  QT_QPA_PLATFORMTHEME= QT_QPA_PLATFORMTHEME_QT6= \
  /path/to/qt/bin/qmltestrunner \
  -import tests/qml/mocks -input tests/qml/tst_buttonstates.qml
```

Replace the Qt path and test filename. The environment settings let tests run
without a visible window and avoid interference from desktop themes.

## Add a test

1. Create a `tst_<feature>.qml` file in this directory.
2. Use an existing test as a starting point, such as [tst_buttonstates.qml](tst_buttonstates.qml).
3. Put checks in functions named `test_<behavior>` inside a `TestCase`.
4. Run the UI tests again. New files are picked up automatically.

Use the fake services in `mocks/` when a component needs application data.
These let tests check layouts, selection, resizing, and navigation without Rust
services or network requests. Actual Rust/Qt integration is checked separately
by the bridge test suite.

## What still needs a manual check?

These tests don't check live YouTube playback, online dictionaries, or actual
video decoding. Try those in the app when your change affects them.

Some standalone tests emit icon or QSettings warnings. Read the failed test and
its assertion to identify a failure; warnings alone don't mean the app failed to build.
