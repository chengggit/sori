Run the QML tests from the repository root with the selected Qt SDK's runner:

```sh
qmltestrunner -import tests/qml/mocks -input tests/qml
```

The mocks provide an offline YouTube service for the discovery pagination test.
For headless runs, set `QT_QPA_PLATFORM=offscreen` and
`QT_QUICK_BACKEND=software`. If a desktop platform theme requires a display,
clear `QT_QPA_PLATFORMTHEME` and `QT_QPA_PLATFORMTHEME_QT6` as well.
