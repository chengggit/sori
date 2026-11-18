pragma Singleton

import QtQuick
import QtCore

QtObject {
    readonly property var styleHints: Qt.styleHints
    readonly property bool dark: preferences.appearance === "dark"
        || (preferences.appearance === "system" && styleHints.colorScheme === Qt.ColorScheme.Dark)
    property alias appearance: preferences.appearance

    property Settings store: Settings {
        id: preferences
        category: "Appearance"
        property string appearance: "system"
    }

    // sRGB equivalents of the OKLCH palette in the original Svelte src/routes/layout.css.
    readonly property color background: dark ? "#0a0a0a" : "#f2f4f2"
    readonly property color sidebar: dark ? "#171717" : "#fafbfa"
    readonly property color neutralHover: dark ? "#262626" : "#f3f3f3"
    readonly property color card: dark ? "#171717" : "#fbfcfb"
    readonly property color foreground: dark ? "#fafafa" : "#0a0a0a"
    readonly property color mutedForeground: dark ? "#a1a1a1" : "#595d59"
    readonly property color border: dark ? "#1a1a1a" : "#e1e4e0"
    readonly property color sidebarBorder: dark ? "#2e2e2e" : border
    readonly property color sidebarSelection: dark ? "#262626" : "#e1e7d7"
    readonly property color sidebarActiveText: dark ? foreground : dashboardAccent
    readonly property color primary: dark ? "#e5e5e5" : "#242c1a"
    readonly property color primaryForeground: dark ? "#171717" : "#fafafa"
    readonly property color accent: dark ? "#aac991" : "#55733f"
    readonly property color onAccent: dark ? "#182212" : "#ffffff"
    readonly property color accentHover: dark ? "#bedaab" : "#4d693a"
    readonly property color accentPressed: dark ? "#cce5b9" : "#466233"
    readonly property color accentSoft: dark ? "#34432b" : "#dde4d3"
    readonly property color accentSoftHover: dark ? "#3c4d31" : "#dce7d3"
    readonly property color disabledAccent: dark ? "#627255" : "#a8b0a2"
    readonly property color hero: dark ? "#1f2619" : "#e4ecdc"
    readonly property color chip: dark ? "#2a3224" : "#e0e6d6"
    readonly property color dashboardAccent: dark ? "#9ec378" : "#436717"
    readonly property color dashboardProgress: dark ? "#9ec378" : "#70934a"
    readonly property color resumeCard: Qt.tint(hero, Qt.alpha(card, 0.75))
    readonly property color destructive: dark ? "#f4a096" : "#b84a42"

    readonly property color darkBackground: "#121212"
    readonly property color darkSurface: "#191919"
    readonly property color darkBorder: "#303030"
    readonly property color darkMuted: "#bcbcbc"
    readonly property color darkForeground: "#f4f4f4"

    readonly property int readerTextWidth: 768
    readonly property int readerHeaderWidth: 1088
    readonly property int readerAnalysisWidth: 500
    readonly property int readerTextSize: 16
    readonly property int readerLineHeight: 40
    readonly property int transcriptLineHeight: 28
    readonly property int readerUnderlineOffset: 4
    readonly property int readerPadding: 24

    readonly property int scrollBarThickness: 4
    readonly property int scrollBarHideDelay: 650
    readonly property color scrollBarColor: "#6e6e6e"
    readonly property real scrollBarOpacity: 0.36
    readonly property real scrollBarActiveOpacity: 0.56

    readonly property int radiusSmall: 8
    readonly property int radius: 12
    readonly property int radiusLarge: 20

    readonly property int iconSize: 16
    readonly property int headerHeight: 56
    readonly property int inputHeight: 38
    readonly property int iconButtonSize: 36
    readonly property int compactControlHeight: 32
    readonly property int searchInputWidth: 460

    // Watch pages use the original player column width.
    readonly property int watchWidth: 920

    // History uses the original page's max-w-6xl text width.
    readonly property int historyWidth: 1088

    // Home uses the original dashboard's content width and spacing.
    readonly property int dashboardWidth: 1528
    readonly property int pageInset: 32
    readonly property int dashboardPadding: 28
    readonly property int dashboardSectionGap: 24
    readonly property int dashboardRowGap: 28
    readonly property int dashboardColumnGap: 20
    readonly property int dashboardBottomPadding: 40
    readonly property int videoTitleLineHeight: 20
    readonly property int videoChannelHeight: 16
    readonly property int controlGap: 8
    readonly property int resumeThumbnailWidth: 224
    readonly property int resumeProgressWidth: 512
    readonly property int progressHeight: 8
}
