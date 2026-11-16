import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Sori 1.0
import "../style"
import "../components"

Item {
    id: root

    required property var player
    required property var subtitles
    required property var renderHost
    required property bool fullScreen
    required property bool controlsAwake
    required property bool captionsVisible
    required property bool nativeText
    required property string libraryError
    required property real videoId
    required property string backLabel

    signal wakeControlsRequested()
    signal toggleFullscreenRequested()
    signal captionsToggleRequested()
    signal openVideoRequested()
    signal openSubtitlesRequested()
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

    WordAnalysis {
        id: wordAnalysis
        parent: Overlay.overlay
        sourceKind: "local"
        sourceId: root.videoId
        x: parent.width - width - 20
        y: root.fullScreen ? 20 : 76
    }

    component WatchText: Text {
        font.family: "Inter"
        renderType: root.textMode
    }

    component PlaybackButton: Button {
        id: button
        property string iconName: ""
        implicitWidth: 36
        implicitHeight: 34
        hoverEnabled: true
        background: Rectangle {
            radius: 6
            color: button.hovered || button.down || button.activeFocus ? "#40ffffff" : "transparent"
        }
        contentItem: Item {
            Icon {
                anchors.centerIn: parent
                visible: button.iconName !== ""
                name: button.iconName
                size: 16
                color: "white"
            }
            WatchText {
                anchors.centerIn: parent
                text: button.text
                visible: button.iconName === ""
                color: "white"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }
    }

    Rectangle {
        id: watchHeader
        visible: !root.fullScreen
        width: parent.width
        height: 56
        color: Theme.background

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 48, 1088)
            height: parent.height

            AppButton {
                anchors.verticalCenter: parent.verticalCenter
                text: root.backLabel
                iconName: "arrow-left"
                variant: "ghost"
                small: true
                onClicked: root.backRequested()
            }
        }
    }

    Rectangle {
        id: stage
        width: height * 16 / 9
        height: root.fullScreen ? Math.min(root.height, root.width * 9 / 16)
            : Math.min(root.height - 218, 517, (root.width - 48) * 9 / 16)
        x: Math.round((root.width - width) / 2)
        y: root.fullScreen ? Math.round((root.height - height) / 2) : watchHeader.height + 24
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
            height: 66
            visible: root.showControls
            color: "#bb000000"

            HoverHandler {
                id: controlHover
                onHoveredChanged: root.wakeControls()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5
                anchors.leftMargin: 20
                anchors.rightMargin: 20
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
                    background: Rectangle {
                        x: timeline.leftPadding
                        y: timeline.topPadding + (timeline.availableHeight - height) / 2
                        width: timeline.availableWidth
                        height: 4
                        radius: 2
                        color: "#737373"
                        Rectangle {
                            width: parent.width * timeline.position
                            height: parent.height
                            radius: parent.radius
                            color: "white"
                        }
                    }
                    handle: Rectangle {
                        x: timeline.leftPadding + timeline.visualPosition * (timeline.availableWidth - width)
                        y: timeline.topPadding + (timeline.availableHeight - height) / 2
                        implicitWidth: 14
                        implicitHeight: 14
                        radius: 7
                        color: "white"
                    }
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
                    PlaybackButton {
                        iconName: root.player.paused || root.player.ended ? "play" : "pause"
                        Accessible.name: root.player.ended ? "Replay" : root.player.paused ? "Play" : "Pause"
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
                    PlaybackButton {
                        text: "CC"
                        objectName: "ccButton"
                        Accessible.name: "Subtitle and audio settings"
                        onClicked: {
                            if (trackMenu.opened) trackMenu.close()
                            else trackMenu.open()
                            root.wakeControls()
                        }
                    }
                    PlaybackButton {
                        iconName: root.fullScreen ? "minimize" : "maximize"
                        Accessible.name: root.fullScreen ? "Exit fullscreen" : "Fullscreen"
                        onClicked: root.toggleFullscreenRequested()
                    }
                }
            }
        }

        Popup {
            id: trackMenu
            objectName: "subtitleSettings"
            x: stage.width - width - 8
            y: Math.max(0, stage.height - controls.height - height - 14)
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
                Label { text: "Audio track"; visible: audioTracks.count > 1 }
                ComboBox {
                    id: audioTracks
                    visible: count > 1
                    Accessible.name: "Audio track"
                    Layout.fillWidth: true
                    model: root.player.audioTracks
                    currentIndex: root.player.audioIndex
                    onActivated: index => root.player.selectAudio(index)
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Volume" }
                    Slider {
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: 100
                        Accessible.name: "Volume"
                        onMoved: root.player.volume(value)
                    }
                }
                AppButton {
                    text: "Attach SRT or VTT"
                    variant: "outline"
                    visible: root.fullScreen
                    onClicked: root.openSubtitlesRequested()
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
        visible: !root.fullScreen && root.player.loaded
        width: Math.min(root.width - 48, 1088)
        anchors.horizontalCenter: parent.horizontalCenter
        y: stage.y + stage.height + 16
        spacing: 20

        AppText {
            text: root.player.filename.replace(/\.[^.]+$/, "")
            font.pixelSize: 20
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 64
            radius: 14
            border.color: Theme.border
            color: Theme.card

            AppButton {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "Attach SRT or VTT"
                iconName: "file-text"
                variant: "outline"
                small: true
                onClicked: root.openSubtitlesRequested()
            }
        }

        AppText {
            Layout.fillWidth: true
            text: root.libraryError || root.subtitles.error
            visible: text !== ""
            color: Theme.destructive
            wrapMode: Text.Wrap
        }
    }
}
