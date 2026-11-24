Run all registered suites with `./scripts/dev test`. For direct CTest use,
build `sori-bridge-test` first. The native `bridge` suite validates the same
response envelopes against real Rust models; these QML tests use mocked services.

To run QML regressions directly, use the selected Qt SDK's runner:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic \
    QT_QPA_PLATFORMTHEME= QT_QPA_PLATFORMTHEME_QT6= \
    /path/to/qt/bin/qmltestrunner -import tests/qml/mocks -input tests/qml
```

The mocks replace Rust services and the embedded YouTube player for offline
regressions. Tests exercise real page components, including playback checkpoints,
transcript cue selection, and discovery pagination. They do not validate live
YouTube playback or remote dictionary availability. Icon and QSettings warnings
from the standalone runner do not indicate an application build failure.
