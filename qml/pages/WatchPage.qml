import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
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
    required property string libraryError
    required property real videoId
    required property string backLabel

    signal wakeControlsRequested()
    signal toggleFullscreenRequested()
    signal captionsToggleRequested()
    signal openVideoRequested()
    signal openSubtitlesRequested()
    signal backRequested()

    readonly property var trackMenu: trackMenu
    readonly property bool analysisOpened: wordAnalysis.visible || subtitleDefinition.visible
    readonly property int textMode: Text.NativeRendering
    property real volumeLevel: 100
    property real previousVolumeLevel: 100
    readonly property bool showControls: player.loaded && (controlsAwake || player.paused
        || player.ended || timeline.pressed || trackMenu.opened || controlHover.hovered)

    palette.window: Theme.background
    palette.base: Theme.card
    palette.button: Theme.card
    palette.buttonText: Theme.foreground
    palette.text: Theme.foreground
    palette.windowText: Theme.foreground
    palette.highlight: Theme.accent
    palette.highlightedText: Theme.onAccent

    function wakeControls() { root.wakeControlsRequested() }

    function closeAnalysis() {
        wordAnalysis.close()
        subtitleDefinition.close()
    }

    onFullScreenChanged: closeAnalysis()
    onCaptionsVisibleChanged: if (!captionsVisible) subtitleDefinition.close()

    WordAnalysis {
        id: wordAnalysis
        parent: Overlay.overlay
        sourceKind: "local"
        sourceId: root.videoId
        x: parent.width - width - 20
        y: 76
    }

    SubtitleDefinition {
        id: subtitleDefinition
        objectName: "subtitleDefinition"
        parent: stage
        videoId: root.videoId
        width: Math.min(352, root.width - 32)
        maximumHeight: Math.max(0, Math.min(root.height * 0.45, stage.y + captionBox.y - 28))
        x: Math.round((stage.width - width) / 2)
        y: Math.floor(captionBox.y - height - 12)
        onAboutToHide: primary.deselect()
    }

    component WatchText: Text {
        font.family: "Inter"
        renderType: root.textMode
    }

    component PlaybackButton: Button {
        id: button
        property string iconName: ""
        implicitWidth: 30
        implicitHeight: 30
        hoverEnabled: true
        background: Rectangle {
            radius: 6
            color: button.hovered || button.down ? "#40ffffff" : "transparent"
        }
        contentItem: Item {
            Icon {
                anchors.centerIn: parent
                visible: button.iconName !== ""
                name: button.iconName
                size: 14
                color: "white"
            }
            WatchText {
                anchors.centerIn: parent
                text: button.text
                visible: button.iconName === ""
                color: "white"
                font.pixelSize: button.text === "CC" ? 12 : 14
                font.weight: Font.DemiBold
            }
        }
    }

    component MenuLabel: WatchText {
        color: Theme.mutedForeground
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    component MenuCombo: ComboBox {
        id: combo

        Layout.fillWidth: true
        implicitHeight: 34
        font.family: "Inter"
        font.pixelSize: 13
        hoverEnabled: true

        background: Rectangle {
            radius: Theme.radiusSmall
            color: combo.enabled ? combo.popup.visible ? Theme.neutralHover : combo.hovered ? Theme.neutralHover : Theme.card
                : Theme.background
            border.width: 1
            border.color: combo.activeFocus ? Theme.accent : Theme.border

            Behavior on color {
                ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        contentItem: WatchText {
            leftPadding: 10
            rightPadding: 28
            text: combo.displayText
            color: combo.enabled ? Theme.foreground : Theme.mutedForeground
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Icon {
            x: combo.width - width - 10
            y: (combo.height - height) / 2
            name: "chevron-down"
            size: 12
            color: combo.enabled ? Theme.mutedForeground : Theme.border
        }

        delegate: ItemDelegate {
            id: option
            required property var modelData
            required property int index

            width: combo.width - combo.popup.padding * 2
            height: 32
            highlighted: combo.highlightedIndex === index

            contentItem: WatchText {
                leftPadding: 6
                rightPadding: 8
                text: option.modelData
                color: Theme.foreground
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Rectangle {
                radius: 6
                color: option.highlighted || option.hovered ? Theme.neutralHover : "transparent"
            }
        }

        popup: Popup {
            y: combo.height + 4
            width: combo.width
            padding: 4

            background: Rectangle {
                radius: Theme.radiusSmall
                color: Theme.card
                border.width: 1
                border.color: Theme.border
            }

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex

                ScrollIndicator.vertical: ScrollIndicator { }
            }
        }
    }

    component MenuCheck: CheckBox {
        id: check

        Layout.fillWidth: true
        spacing: 10
        padding: 0
        hoverEnabled: true

        contentItem: WatchText {
            leftPadding: check.indicator.width + check.spacing
            text: check.text
            color: Theme.foreground
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Rectangle {
            x: check.leftPadding
            y: (check.height - height) / 2
            implicitWidth: 16
            implicitHeight: 16
            radius: 4
            color: check.checked ? Theme.accent : Theme.card
            border.width: check.checked ? 0 : 1
            border.color: check.hovered ? Theme.mutedForeground : Theme.border

            Shape {
                anchors.fill: parent
                visible: check.checked
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 2
                    strokeColor: Theme.dark ? "#000000" : "#ffffff"
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M 4 8 L 7 11 L 12 5" }
                }
            }
        }
    }

    component MenuButton: Button {
        id: button

        implicitHeight: 32
        hoverEnabled: true

        contentItem: Item {
            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Icon {
                    name: "file-text"
                    size: 13
                    color: Theme.foreground
                }
                WatchText {
                    text: button.text
                    color: Theme.foreground
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }

        background: Rectangle {
            radius: Theme.radiusSmall
            color: button.hovered || button.down ? Theme.neutralHover : "transparent"
            border.width: 1
            border.color: Theme.border
        }
    }

    Item {
        id: watchHeader
        visible: !root.fullScreen
        anchors.top: parent.top
        anchors.topMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width - 48, Theme.watchWidth)
        height: backButton.implicitHeight

        AppButton {
            id: backButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.backLabel
            iconName: "arrow-left"
            variant: "ghost"
            onClicked: root.backRequested()
        }
    }

    Rectangle {
        id: stageMask
        anchors.fill: stage
        radius: 14
        visible: false
        layer.enabled: !root.fullScreen
        layer.smooth: true
    }

    Rectangle {
        id: stage
        width: height * 16 / 9
        height: root.fullScreen ? Math.min(root.height, root.width * 9 / 16)
            : Math.min(root.height - 218,
                Math.min(root.width - 48, Theme.watchWidth) * 9 / 16)
        x: Math.round((root.width - width) / 2)
        y: root.fullScreen ? Math.round((root.height - height) / 2)
            : watchHeader.y + watchHeader.height + 16
        color: "#000000"
        radius: root.fullScreen ? 0 : stageMask.radius
        clip: true

        Item {
            anchors.fill: parent
            // Mask the video surface while keeping text and controls at screen resolution.
            layer.enabled: !root.fullScreen
            layer.smooth: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: stageMask
            }

            VideoSurface {
                objectName: "videoSurface"
                anchors.fill: parent
                host: root.renderHost
            }
        }

        HoverHandler { onPointChanged: root.wakeControls() }
        TapHandler { onDoubleTapped: if (root.player.loaded) root.toggleFullscreenRequested() }

        Rectangle {
            anchors.fill: parent
            visible: !root.player.loaded || root.player.error !== ""
            color: "#000000"
            radius: stage.radius
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
            id: captionBox
            objectName: "captionBox"
            visible: root.player.loaded && root.captionsVisible && (primary.text !== "" || secondary.text !== "")
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.showControls ? controls.height + controls.anchors.bottomMargin + 8 : 15
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
                    persistentSelection: root.fullScreen
                    selectionColor: root.fullScreen ? "transparent" : Theme.accent
                    selectedTextColor: root.fullScreen ? "#fde68a" : Theme.onAccent
                    renderType: root.textMode
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    textFormat: TextEdit.PlainText
                    Accessible.name: "Primary subtitle"
                    onTextChanged: if (subtitleDefinition.visible) subtitleDefinition.close()

                    // Keep the hovered word separate from the word selected for lookup.
                    TextEdit {
                        id: hoverText
                        anchors.fill: parent
                        visible: root.fullScreen
                        enabled: false
                        text: primary.text
                        font: primary.font
                        renderType: primary.renderType
                        horizontalAlignment: primary.horizontalAlignment
                        wrapMode: primary.wrapMode
                        textFormat: TextEdit.PlainText
                        readOnly: true
                        persistentSelection: true
                        color: "transparent"
                        selectionColor: "transparent"
                        selectedTextColor: primary.selectedTextColor
                        Accessible.ignored: true

                        function updateHover() {
                            if (!visible || !subtitleHover.hovered) {
                                deselect()
                                return
                            }
                            const point = subtitleHover.point.position
                            cursorPosition = positionAt(point.x, point.y)
                            selectWord()
                            const first = positionToRectangle(selectionStart)
                            const last = positionToRectangle(selectionEnd)
                            if (!/[가-힣ㄱ-ㆎᄀ-ᇿ]/.test(selectedText)
                                    || point.y < first.y || point.y >= last.y + last.height
                                    || (point.y < first.y + first.height && point.x < first.x)
                                    || (point.y >= last.y && point.x >= last.x))
                                deselect()
                        }

                        onTextChanged: Qt.callLater(updateHover)
                        onWidthChanged: Qt.callLater(updateHover)

                        FontMetrics {
                            id: captionMetrics
                            font: hoverText.font
                        }

                        Repeater {
                            model: {
                                if (!hoverText.selectedText)
                                    return []
                                const segments = []
                                let first = hoverText.positionToRectangle(hoverText.selectionStart)
                                let previous = first
                                for (let i = hoverText.selectionStart + 1; i <= hoverText.selectionEnd; i++) {
                                    const next = hoverText.positionToRectangle(i)
                                    const wraps = next.y !== previous.y
                                    if (wraps || i === hoverText.selectionEnd) {
                                        const edge = wraps ? previous.x
                                            + captionMetrics.advanceWidth(hoverText.text.slice(i - 1, i)) : next.x
                                        segments.push({ x: first.x, y: Math.round(first.y + captionMetrics.ascent
                                            + captionMetrics.underlinePosition + 1), width: Math.max(0, edge - first.x) })
                                    }
                                    if (wraps)
                                        first = next
                                    previous = next
                                }
                                return segments
                            }

                            Shape {
                                id: underline
                                required property var modelData
                                x: modelData.x
                                y: modelData.y
                                width: modelData.width
                                height: 2

                                ShapePath {
                                    strokeColor: hoverText.selectedTextColor
                                    strokeWidth: 2
                                    strokeStyle: ShapePath.DashLine
                                    dashPattern: [0.5, 1.8]
                                    capStyle: ShapePath.RoundCap
                                    fillColor: "transparent"
                                    startY: 1
                                    PathLine { x: underline.width; y: 1 }
                                }
                            }
                        }
                    }

                    HoverHandler {
                        id: subtitleHover
                        enabled: root.fullScreen
                        cursorShape: hoverText.selectedText ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPointChanged: hoverText.updateHover()
                        onHoveredChanged: hoverText.updateHover()
                    }

                    TapHandler {
                        onSingleTapped: (eventPoint, button) => {
                            primary.cursorPosition = primary.positionAt(eventPoint.position.x, eventPoint.position.y)
                            primary.selectWord()
                            if (root.fullScreen && /[가-힣ㄱ-ㆎᄀ-ᇿ]/.test(primary.selectedText)) {
                                root.player.pause()
                                subtitleDefinition.lookup(primary.text, primary.selectionStart, primary.selectionEnd)
                            } else if (!root.fullScreen && primary.selectedText.trim()) {
                                root.player.pause()
                                wordAnalysis.lookup(primary.text, primary.selectionStart, primary.selectionEnd)
                                primary.deselect()
                            } else {
                                subtitleDefinition.close()
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
            height: 60
            visible: root.showControls
            color: "#bb000000"
            radius: 10

            HoverHandler {
                id: controlHover
                onHoveredChanged: root.wakeControls()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5
                anchors.leftMargin: 12
                anchors.rightMargin: 12
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
                    RowLayout {
                        Layout.preferredWidth: 128
                        Layout.minimumWidth: Layout.preferredWidth
                        Layout.maximumWidth: Layout.preferredWidth
                        spacing: 0

                        WatchText {
                            id: elapsedTime
                            Layout.preferredWidth: timeSlot.advanceWidth
                            horizontalAlignment: Text.AlignRight
                            text: root.player.formatTime(timeline.value)
                            color: "#eeeeee"
                            font.pixelSize: 13
                            font.features: ({ "tnum": 1 })
                        }

                        TextMetrics {
                            id: timeSlot
                            font: elapsedTime.font
                            text: root.player.formatTime(root.player.duration).replace(/[0-9]/g, "8")
                        }

                        WatchText {
                            Layout.fillWidth: true
                            text: " / " + root.player.formatTime(root.player.duration)
                            color: "#eeeeee"
                            font: elapsedTime.font
                        }
                    }
                    PlaybackButton {
                        iconName: root.volumeLevel <= 0 ? "volume-x" : "volume"
                        Accessible.name: root.volumeLevel <= 0 ? "Unmute" : "Mute"
                        Layout.leftMargin: 12
                        onClicked: {
                            if (root.volumeLevel > 0) {
                                root.previousVolumeLevel = root.volumeLevel
                                root.volumeLevel = 0
                            } else {
                                root.volumeLevel = Math.max(1, root.previousVolumeLevel)
                            }
                            root.player.volume(root.volumeLevel)
                            root.wakeControls()
                        }
                    }
                    Slider {
                        id: volumeSlider
                        objectName: "volumeControl"
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 21
                        from: 0
                        to: 100
                        value: root.volumeLevel
                        Accessible.name: "Volume"
                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                            width: volumeSlider.availableWidth
                            height: 4
                            radius: 2
                            color: "#737373"
                            Rectangle {
                                width: parent.width * volumeSlider.visualPosition
                                height: parent.height
                                radius: parent.radius
                                color: "white"
                            }
                        }
                        handle: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                            y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                            implicitWidth: 12
                            implicitHeight: 12
                            radius: 6
                            color: "white"
                        }
                        onMoved: {
                            if (value > 0)
                                root.previousVolumeLevel = value
                            root.volumeLevel = value
                            root.player.volume(value)
                            root.wakeControls()
                        }
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
            y: Math.max(0, controls.y - height - 6)
            width: 300
            padding: 14
            focus: true
            onClosed: root.wakeControls()
            background: Rectangle {
                radius: Theme.radius
                color: Theme.card
                border.width: 1
                border.color: Theme.border
            }
            contentItem: ColumnLayout {
                spacing: 10

                MenuLabel { text: "Primary subtitle" }
                MenuCombo {
                    objectName: "primaryTracks"
                    model: root.subtitles.options
                    currentIndex: root.subtitles.primary
                    enabled: count > 1
                    onActivated: index => root.subtitles.select(0, index)
                }

                MenuLabel { text: "Secondary subtitle"; Layout.topMargin: 2 }
                MenuCombo {
                    objectName: "secondaryTracks"
                    model: root.subtitles.options
                    currentIndex: root.subtitles.secondary
                    enabled: count > 1
                    onActivated: index => root.subtitles.select(1, index)
                }

                MenuCheck {
                    Layout.topMargin: 4
                    text: "Show captions"
                    checked: root.captionsVisible
                    onToggled: root.captionsToggleRequested()
                }

                MenuLabel { text: "Audio track"; visible: audioTracks.count > 1; Layout.topMargin: 2 }
                MenuCombo {
                    id: audioTracks
                    visible: count > 1
                    Accessible.name: "Audio track"
                    model: root.player.audioTracks
                    currentIndex: root.player.audioIndex
                    onActivated: index => root.player.selectAudio(index)
                }

                MenuButton {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    text: "Attach SRT or VTT"
                    visible: root.fullScreen
                    onClicked: root.openSubtitlesRequested()
                }

            }
        }
    }

    ColumnLayout {
        visible: !root.fullScreen && root.player.loaded
        width: Math.min(root.width - 48, Theme.watchWidth)
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
