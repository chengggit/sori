import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Sori 1.0
import sori_qt_playback

ApplicationWindow {
    id: root
    required property var renderHost
    required property string startupPath
    readonly property var player: Player
    readonly property var subtitles: Subtitles
    property bool sidebarExpanded: true
    readonly property real contentX: root.fullScreen ? 0 : sidebar.width
    readonly property real contentWidth: width - contentX
    property bool controlsAwake: true
    property bool captionsVisible: true
    property bool followPlayback: true
    property bool nativeText: true
    property int previousVisibility: Window.Windowed
    readonly property bool fullScreen: visibility === Window.FullScreen
    readonly property bool showControls: player.loaded && (controlsAwake || player.paused
        || player.ended || timeline.pressed || trackMenu.opened || controlHover.hovered)
    readonly property int textMode: nativeText ? Text.NativeRendering : Text.QtRendering

    width: 1060
    height: 780
    minimumWidth: 640
    minimumHeight: 480
    visible: true
    title: "Sori · Qt Watch"
    color: fullScreen ? "#000000" : "#121212"
    font.family: "Inter"
    palette.window: "#191919"
    palette.base: "#202020"
    palette.button: "#272727"
    palette.buttonText: "#f0f0f0"
    palette.text: "#f0f0f0"
    palette.windowText: "#f0f0f0"
    palette.highlight: "#587a9b"
    palette.highlightedText: "#ffffff"

    component WatchText: Text {
        font.family: "Inter"
        renderType: root.textMode
    }

    function wakeControls() {
        controlsAwake = true
        hideControls.restart()
    }

    function toggleFullscreen() {
        trackMenu.close()
        if (fullScreen) {
            visibility = previousVisibility
        } else {
            previousVisibility = visibility
            root.showFullScreen()
        }
        wakeControls()
    }

    function followCurrentCue() {
        if (!followPlayback || fullScreen)
            return
        if (subtitles.activeRow >= 0)
            transcript.positionViewAtIndex(subtitles.activeRow, ListView.Center)
        else
            transcript.positionViewAtBeginning()
    }

    onFollowPlaybackChanged: followCurrentCue()
    onFullScreenChanged: Qt.callLater(followCurrentCue)
    Component.onCompleted: {
        wakeControls()
        if (startupPath)
            player.open(startupPath)
    }

    Connections {
        target: root.renderHost
        function onRendererReady(ready) { root.player.rendererReady(ready) }
        function onRendererFailed(result) { root.player.rendererFailed(result) }
    }

    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            root.player.poll()
            if (root.player.loaded && !root.player.paused && !root.player.ended)
                root.renderHost.checkFrame()
        }
    }

    Connections {
        target: root.player
        function onMediaOpening() {
            root.subtitles.reset()
            root.followPlayback = true
            root.captionsVisible = true
            root.wakeControls()
        }
        function onMediaReady(path) {
            root.subtitles.probe(path)
            root.wakeControls()
        }
        function onPositionChanged() { root.subtitles.update(root.player.position) }
    }

    Connections {
        target: root.subtitles
        function onActiveRowChanged() { root.followCurrentCue() }
        function onTranscriptChanged() { Qt.callLater(root.followCurrentCue) }
    }

    Timer {
        id: hideControls
        interval: 2300
        onTriggered: root.controlsAwake = false
    }

    Shortcut {
        sequence: "F"
        enabled: root.player.loaded && !trackMenu.opened
        onActivated: root.toggleFullscreen()
    }
    Shortcut {
        sequence: "Esc"
        enabled: root.fullScreen && !trackMenu.opened
        onActivated: root.toggleFullscreen()
    }
    Shortcut {
        sequence: "C"
        enabled: root.player.loaded && !trackMenu.opened
        onActivated: {
            root.captionsVisible = !root.captionsVisible
            root.wakeControls()
        }
    }
    Shortcut {
        sequence: "Space"
        enabled: root.player.loaded && !trackMenu.opened
        onActivated: {
            root.player.togglePlay()
            root.wakeControls()
        }
    }
    Shortcut {
        sequence: "Left"
        enabled: root.player.loaded && !trackMenu.opened
        onActivated: {
            root.player.seek(root.player.position - 5)
            root.wakeControls()
        }
    }
    Shortcut {
        sequence: "Right"
        enabled: root.player.loaded && !trackMenu.opened
        onActivated: {
            root.player.seek(root.player.position + 5)
            root.wakeControls()
        }
    }

    FileDialog {
        id: videoPicker
        title: "Open a local video"
        nameFilters: ["Video files (*.mkv *.mp4 *.m4v *.mov *.webm *.avi *.ts)", "All files (*)"]
        onAccepted: root.player.open(root.renderHost.localPath(selectedFile))
    }
    FileDialog {
        id: subtitlePicker
        title: "Attach subtitles"
        nameFilters: ["Subtitle files (*.srt *.vtt)", "All files (*)"]
        onAccepted: root.subtitles.attach(root.renderHost.localPath(selectedFile))
    }

    Rectangle {
        id: sidebar
        objectName: "watchSidebar"
        visible: !root.fullScreen
        width: root.sidebarExpanded ? 208 : 48
        height: parent.height
        color: "#181818"
        clip: true
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.Linear } }

        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: "#303030"
        }

        WatchText {
            x: 23
            y: 22
            visible: root.sidebarExpanded
            text: "sori"
            color: "#fafafa"
            font.pixelSize: 18
            font.bold: true
        }

        ToolButton {
            objectName: "sidebarToggle"
            anchors.right: parent.right
            anchors.rightMargin: 7
            y: 16
            width: 34
            height: 34
            text: "◫"
            Accessible.name: root.sidebarExpanded ? "Collapse sidebar" : "Expand sidebar"
            onClicked: root.sidebarExpanded = !root.sidebarExpanded
        }

        Column {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            anchors.topMargin: 84
            spacing: 4

            Repeater {
                model: [
                    { icon: "⌂", label: "Home" },
                    { icon: "◇", label: "Explore" },
                    { icon: "▤", label: "My Library" },
                    { icon: "◷", label: "History" },
                    { icon: "♧", label: "Vocabulary" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: sidebar.width - 16
                    height: 34
                    radius: 10
                    color: modelData.label === "My Library" ? "#2a2a2a" : "transparent"
                    WatchText {
                        x: 8
                        width: 16
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.icon
                        color: "#e3e3e3"
                        font.pixelSize: 16
                    }
                    WatchText {
                        x: 34
                        visible: root.sidebarExpanded
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: modelData.label === "My Library" ? "#eeeeee" : "#aaaaaa"
                        font.pixelSize: 13
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#303030"
            }
        }
    }

    Rectangle {
        id: header
        visible: !root.fullScreen
        x: root.contentX
        width: root.contentWidth
        height: 56
        color: "#191919"
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: "#303030"
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 32
            anchors.rightMargin: 32
            spacing: 12
            WatchText {
                text: "‹  My Library"
                color: "#dddddd"
                font.pixelSize: 14
                Layout.fillWidth: true
            }
            Button {
                text: "Open video"
                enabled: root.player.ready && !root.player.loading
                onClicked: videoPicker.open()
            }
        }
    }

    Rectangle {
        id: stage
        width: height * 16 / 9
        height: root.fullScreen ? Math.min(root.height, root.width * 9 / 16)
            : Math.min(root.height / 2, (root.contentWidth - 64) * 9 / 16)
        x: root.contentX + Math.round((root.contentWidth - width) / 2)
        y: root.fullScreen ? Math.round((root.height - height) / 2) : 80
        color: "#000000"
        clip: true

        VideoSurface {
            objectName: "videoSurface"
            anchors.fill: parent
            host: root.renderHost
        }

        HoverHandler {
            onPointChanged: root.wakeControls()
        }
        TapHandler {
            onDoubleTapped: if (root.player.loaded) root.toggleFullscreen()
        }

        Rectangle {
            anchors.fill: parent
            visible: !root.player.loaded || root.player.error !== ""
            color: "#000000"
            WatchText {
                anchors.centerIn: parent
                width: parent.width - 40
                text: root.player.error || (root.player.loading ? "Opening video…" : "Open a local video to start")
                color: root.player.error ? "#ffb4ac" : "#bbbbbb"
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
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
                WatchText {
                    id: primary
                    objectName: "primaryCaption"
                    width: parent.width
                    text: root.subtitles.primaryText
                    visible: text !== ""
                    color: "white"
                    font.family: "Noto Sans KR"
                    font.pixelSize: root.fullScreen ? 28 : 21
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
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
                    Button {
                        text: root.player.ended ? "Replay" : root.player.paused ? "Play" : "Pause"
                        Layout.preferredWidth: 68
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
                    Button {
                        text: "CC"
                        objectName: "ccButton"
                        Accessible.name: "Subtitle settings"
                        onClicked: {
                            if (trackMenu.opened) trackMenu.close()
                            else trackMenu.open()
                            root.wakeControls()
                        }
                    }
                    Button {
                        text: root.fullScreen ? "Exit fullscreen" : "Fullscreen"
                        onClicked: root.toggleFullscreen()
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
                    onToggled: root.captionsVisible = checked
                }
                CheckBox {
                    text: "Native text rendering"
                    checked: root.nativeText
                    onToggled: root.nativeText = checked
                }
            }
        }
    }

    ColumnLayout {
        id: details
        visible: !root.fullScreen && root.player.loaded
        width: Math.min(root.contentWidth - 64, 1088)
        x: root.contentX + Math.round((root.contentWidth - width) / 2)
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
                    Button { text: "Attach SRT or VTT"; onClicked: subtitlePicker.open() }
                    CheckBox {
                        text: "Follow playback"
                        checked: root.followPlayback
                        enabled: transcript.count > 0
                        onToggled: root.followPlayback = checked
                    }
                }

                WatchText {
                    visible: root.subtitles.error !== "" || root.subtitles.loading || !transcript.count
                    Layout.fillWidth: true
                    text: root.subtitles.error || (root.subtitles.loading
                        ? "Loading subtitles…" : "Select a track in CC or attach a subtitle file.")
                    color: root.subtitles.error ? "#ffb4ac" : "#bcbcbc"
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
                    onMovementStarted: root.followPlayback = false
                    Accessible.name: "Subtitle transcript"
                    ScrollBar.vertical: ScrollBar {
                        onPressedChanged: if (pressed) root.followPlayback = false
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
