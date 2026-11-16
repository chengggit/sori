import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Sori 1.0
import "../Theme.js" as Theme
import "../components"

Item {
    id: root

    required property var player
    required property var subtitles
    required property var renderHost
    required property bool fullScreen
    required property bool controlsAwake
    required property bool captionsVisible
    required property bool followPlayback
    required property bool nativeText
    required property string libraryError
    required property real videoId

    signal wakeControlsRequested()
    signal toggleFullscreenRequested()
    signal captionsToggleRequested()
    signal openVideoRequested()
    signal openSubtitlesRequested()
    signal followPlaybackRequested(bool follow)
    signal nativeTextRequested(bool enabled)
    signal backRequested()

    readonly property var trackMenu: trackMenu
    readonly property bool analysisOpened: wordAnalysis.visible
    readonly property int textMode: nativeText ? Text.NativeRendering : Text.QtRendering
    readonly property bool showControls: player.loaded && (controlsAwake || player.paused
        || player.ended || timeline.pressed || trackMenu.opened || controlHover.hovered)

    palette.window: "#191919"
    palette.base: "#202020"
    palette.button: "#272727"
    palette.buttonText: "#f0f0f0"
    palette.text: "#f0f0f0"
    palette.windowText: "#f0f0f0"
    palette.highlight: "#587a9b"
    palette.highlightedText: "#ffffff"

    function wakeControls() { root.wakeControlsRequested() }

    function closeAnalysis() { wordAnalysis.close() }

    function followCurrentCue() {
        if (!root.followPlayback || root.fullScreen)
            return
        if (root.subtitles.activeRow >= 0)
            transcript.positionViewAtIndex(root.subtitles.activeRow, ListView.Center)
        else
            transcript.positionViewAtBeginning()
    }

    onFollowPlaybackChanged: followCurrentCue()
    onFullScreenChanged: Qt.callLater(followCurrentCue)

    WordAnalysis {
        id: wordAnalysis
        parent: Overlay.overlay
        sourceKind: "local"
        sourceId: root.videoId
        x: parent.width - width - 20
        y: root.fullScreen ? 20 : 76
    }

    Connections {
        target: root.subtitles
        function onActiveRowChanged() { root.followCurrentCue() }
        function onTranscriptChanged() { Qt.callLater(root.followCurrentCue) }
    }

    component WatchText: Text {
        font.family: "Inter"
        renderType: root.textMode
    }

    Rectangle {
        id: watchHeader
        visible: !root.fullScreen
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        color: Theme.darkSurface

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.darkBorder
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 12

            Item {
                Layout.preferredWidth: backRow.implicitWidth
                Layout.fillHeight: true
                RowLayout {
                    id: backRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Icon { name: "arrow-left"; size: 16; color: "#dddddd" }
                    WatchText { text: "Back"; color: "#dddddd"; font.pixelSize: 13 }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }
            }
            Item { Layout.fillWidth: true }
            AppButton {
                text: "Open video"
                iconName: "play"
                small: true
                enabled: root.player.ready && !root.player.loading
                onClicked: root.openVideoRequested()
            }
        }
    }

    Rectangle {
        id: stage
        width: height * 16 / 9
        height: root.fullScreen ? Math.min(root.height, root.width * 9 / 16)
            : Math.min(root.height / 2, (root.width - 64) * 9 / 16)
        x: Math.round((root.width - width) / 2)
        y: root.fullScreen ? Math.round((root.height - height) / 2) : watchHeader.height + 16
        color: "#000000"
        clip: true

        VideoSurface {
            objectName: "videoSurface"
            anchors.fill: parent
            host: root.renderHost
        }

        HoverHandler { onPointChanged: root.wakeControls() }
        TapHandler { onDoubleTapped: if (root.player.loaded) root.toggleFullscreenRequested() }

        Rectangle {
            anchors.fill: parent
            visible: !root.player.loaded || root.player.error !== ""
            color: "#000000"
            Column {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 10
                WatchText {
                    width: parent.width
                    text: root.player.error || (root.player.loading ? "Opening video…" : "Open a local video to start")
                    color: root.player.error ? "#ffb4ac" : "#bbbbbb"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
                AppButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !root.player.loading
                    text: "Open video"
                    iconName: "play"
                    enabled: root.player.ready
                    onClicked: root.openVideoRequested()
                }
            }
        }

        Rectangle {
            objectName: "captionBox"
            visible: root.player.loaded && root.captionsVisible && (primary.text !== "" || secondary.text !== "")
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.showControls ? controls.height + 15 : 15
            width: Math.min(stage.width - 28, Math.max(primary.implicitWidth, secondary.implicitWidth) + 24)
            height: lines.implicitHeight + 10
            color: "#d9000000"
            radius: 6

            Column {
                id: lines
                anchors.fill: parent
                anchors.margins: 5
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 3
                TextEdit {
                    id: primary
                    objectName: "primaryCaption"
                    width: parent.width
                    text: root.subtitles.primaryText
                    visible: text !== ""
                    color: "white"
                    font.family: "Noto Sans KR"
                    font.pixelSize: root.fullScreen ? 28 : 21
                    readOnly: true
                    renderType: root.textMode
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    textFormat: TextEdit.PlainText
                    Accessible.name: "Primary subtitle"

                    TapHandler {
                        onSingleTapped: (eventPoint, button) => {
                            primary.cursorPosition = primary.positionAt(eventPoint.position.x, eventPoint.position.y)
                            primary.selectWord()
                            if (primary.selectedText.trim()) {
                                root.player.pause()
                                wordAnalysis.lookup(primary.text, primary.selectionStart, primary.selectionEnd)
                                primary.deselect()
                            }
                        }
                    }
                }
                WatchText {
                    id: secondary
                    objectName: "secondaryCaption"
                    width: parent.width
                    text: root.subtitles.secondaryText
                    visible: text !== ""
                    color: "#eeeeee"
                    font.family: "Noto Sans KR"
                    font.pixelSize: root.fullScreen ? 20 : 17
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                }
            }
        }

        Rectangle {
            id: controls
            objectName: "playbackControls"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8
            height: 66
            visible: root.showControls
            color: "#bb000000"
            radius: 8

            HoverHandler {
                id: controlHover
                onHoveredChanged: root.wakeControls()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                spacing: 2

                Slider {
                    id: timeline
                    objectName: "timeline"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 21
                    enabled: root.player.duration > 0
                    from: 0
                    to: Math.max(1, root.player.duration)
                    property real scrubTime: 0
                    Accessible.name: "Playback position"
                    onPressedChanged: {
                        if (pressed)
                            scrubTime = value
                        else
                            root.player.seek(scrubTime)
                        root.wakeControls()
                    }
                    onMoved: {
                        scrubTime = value
                        if (!pressed)
                            root.player.seek(value)
                        root.wakeControls()
                    }
                    Binding on value {
                        when: !timeline.pressed
                        restoreMode: Binding.RestoreNone
                        value: root.player.position
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7
                    AppButton {
                        text: root.player.ended ? "Replay" : root.player.paused ? "Play" : "Pause"
                        Layout.preferredWidth: 68
                        small: true
                        onClicked: {
                            root.player.togglePlay()
                            root.wakeControls()
                        }
                    }
                    WatchText {
                        text: root.player.formatTime(timeline.value) + " / " + root.player.formatTime(root.player.duration)
                        color: "#eeeeee"
                        font.pixelSize: 13
                    }
                    Item { Layout.fillWidth: true }
                    Slider {
                        from: 0
                        to: 100
                        value: 100
                        Layout.preferredWidth: 68
                        Accessible.name: "Volume"
                        onMoved: root.player.volume(value)
                    }
                    AppButton {
                        text: "CC"
                        objectName: "ccButton"
                        Accessible.name: "Subtitle settings"
                        small: true
                        onClicked: {
                            if (trackMenu.opened) trackMenu.close()
                            else trackMenu.open()
                            root.wakeControls()
                        }
                    }
                    AppButton {
                        text: root.fullScreen ? "Exit fullscreen" : "Fullscreen"
                        small: true
                        onClicked: root.toggleFullscreenRequested()
                    }
                }
            }
        }

        Popup {
            id: trackMenu
            objectName: "subtitleSettings"
            x: stage.width - width - 8
            y: stage.height - controls.height - height - 14
            width: 280
            padding: 10
            focus: true
            onClosed: root.wakeControls()
            background: Rectangle { color: "#222222"; radius: 8; border.color: "#3a3a3a" }
            contentItem: ColumnLayout {
                spacing: 4
                Label { text: "Primary subtitle" }
                ComboBox {
                    objectName: "primaryTracks"
                    Layout.fillWidth: true
                    model: root.subtitles.options
                    currentIndex: root.subtitles.primary
                    enabled: count > 1
                    onActivated: index => root.subtitles.select(0, index)
                }
                Label { text: "Secondary subtitle" }
                ComboBox {
                    objectName: "secondaryTracks"
                    Layout.fillWidth: true
                    model: root.subtitles.options
                    currentIndex: root.subtitles.secondary
                    enabled: count > 1
                    onActivated: index => root.subtitles.select(1, index)
                }
                CheckBox {
                    text: "Show captions"
                    checked: root.captionsVisible
                    onToggled: root.captionsToggleRequested()
                }
                CheckBox {
                    text: "Native text rendering"
                    checked: root.nativeText
                    onToggled: root.nativeTextRequested(checked)
                }
            }
        }
    }

    ColumnLayout {
        id: details
        visible: !root.fullScreen && root.player.loaded
        width: Math.min(root.width - 64, 1088)
        x: Math.round((root.width - width) / 2)
        y: stage.y + stage.height + 12
        height: Math.max(0, root.height - y - 14)
        spacing: 9

        RowLayout {
            Layout.fillWidth: true
            WatchText {
                text: root.player.filename
                color: "#fafafa"
                font.pixelSize: 19
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            WatchText {
                text: root.player.details + "  ·  " + root.player.dropped + " dropped"
                color: "#bcbcbc"
                font.pixelSize: 13
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            border.color: "#313131"
            color: "#191919"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5

                RowLayout {
                    spacing: 9
                    WatchText {
                        text: "Subtitles"
                        color: "#eeeeee"
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    ComboBox {
                        Accessible.name: "Audio track"
                        Layout.preferredWidth: 154
                        model: root.player.audioTracks
                        currentIndex: root.player.audioIndex
                        enabled: count > 1
                        onActivated: index => root.player.selectAudio(index)
                    }
                    AppButton { text: "Attach SRT or VTT"; small: true; onClicked: root.openSubtitlesRequested() }
                    CheckBox {
                        text: "Follow playback"
                        checked: root.followPlayback
                        enabled: transcript.count > 0
                        onToggled: root.followPlaybackRequested(checked)
                    }
                }

                WatchText {
                    visible: root.libraryError !== "" || root.subtitles.error !== "" || root.subtitles.loading || !transcript.count
                    Layout.fillWidth: true
                    text: root.libraryError || root.subtitles.error || (root.subtitles.loading
                        ? "Loading subtitles…" : "Select a track in CC or attach a subtitle file.")
                    color: root.libraryError || root.subtitles.error ? "#ffb4ac" : "#bcbcbc"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                ListView {
                    id: transcript
                    objectName: "transcript"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.subtitles.transcript
                    onMovementStarted: root.followPlaybackRequested(false)
                    Accessible.name: "Subtitle transcript"
                    ScrollBar.vertical: ScrollBar {
                        onPressedChanged: if (pressed) root.followPlaybackRequested(false)
                    }
                    delegate: Rectangle {
                        id: cue
                        required property var modelData
                        readonly property bool current: root.player.position >= modelData.start
                            && root.player.position < modelData.end
                        width: transcript.width - 14
                        height: 64
                        radius: 6
                        color: current ? "#333029" : cueHit.containsMouse ? "#242424" : "transparent"
                        Accessible.role: Accessible.Button
                        Accessible.name: textLine.text
                        Accessible.onPressAction: root.player.seek(modelData.start)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 12
                            WatchText {
                                text: root.player.formatTime(cue.modelData.start)
                                color: "#b7aa90"
                                font.pixelSize: 13
                                Layout.preferredWidth: 50
                            }
                            WatchText {
                                id: textLine
                                text: cue.modelData.text
                                color: cue.modelData.secondary ? "#bcbcbc" : "#f4f4f4"
                                font.family: "Noto Sans KR"
                                font.pixelSize: cue.modelData.secondary ? 14 : 16
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                            }
                        }
                        MouseArea {
                            id: cueHit
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.player.seek(cue.modelData.start)
                        }
                    }
                }
            }
        }
    }
}
