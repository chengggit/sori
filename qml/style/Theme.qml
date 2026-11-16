pragma Singleton

import QtQuick
import QtCore

QtObject {
    readonly property var styleHints: Qt.styleHints
    readonly property bool dark: preferences.appearance === "dark"
        || (preferences.appearance === "system" && styleHints.colorScheme === Qt.ColorScheme.Dark)
    property alias appearance: preferences.appearance
    property alias nativeText: preferences.nativeText

    property Settings store: Settings {
        id: preferences
        category: "Appearance"
        property string appearance: "system"
        property bool nativeText: true
    }

    readonly property color background: dark ? "#181b16" : "#f7f8f3"
    readonly property color sidebar: dark ? "#1d211b" : "#fbfcf8"
    readonly property color card: dark ? "#232720" : "#ffffff"
    readonly property color foreground: dark ? "#eef0e8" : "#20251d"
    readonly property color mutedForeground: dark ? "#aeb8a7" : "#6f766b"
    readonly property color border: dark ? "#3b4337" : "#e2e6da"
    readonly property color accent: dark ? "#aac991" : "#55733f"
    readonly property color onAccent: dark ? "#182212" : "#ffffff"
    readonly property color accentHover: dark ? "#bedaab" : "#4d693a"
    readonly property color accentPressed: dark ? "#cce5b9" : "#466233"
    readonly property color accentSoft: dark ? "#34432b" : "#e6eddf"
    readonly property color accentSoftHover: dark ? "#3c4d31" : "#dce7d3"
    readonly property color disabledAccent: dark ? "#627255" : "#a8b0a2"
    readonly property color hero: dark ? "#2a3424" : "#edf2e7"
    readonly property color chip: dark ? "#35432d" : "#e9eee2"
    readonly property color destructive: dark ? "#f4a096" : "#b84a42"

    readonly property color darkBackground: "#121212"
    readonly property color darkSurface: "#191919"
    readonly property color darkBorder: "#303030"
    readonly property color darkMuted: "#bcbcbc"
    readonly property color darkForeground: "#f4f4f4"

    readonly property int radiusSmall: 8
    readonly property int radius: 12
    readonly property int radiusLarge: 20
}
