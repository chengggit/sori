import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import "../style"

Rectangle {
    id: root
    required property var subtitles
    required property var player
    signal lookupRequested(string text, int start, int end)
    signal addRequested()
    property string emptyAction: "Add subtitle files"
    property string emptyHint: "Select a primary text track in CC or add an SRT or VTT file."
    color: Theme.card
    border.color: Theme.border
    radius: Theme.radius

    property bool following: true
    property int followingRow: -1

    function pauseFollow() {
        following = false
        scrollAnimation.stop()
        resumeDelay.restart()
    }

    function noteActivity() {
        if (!following)
            resumeDelay.restart()
    }

    function scrollToRow(index, settling = false) {
        if (index < 0 || index >= lines.count || lines.height <= 0 || !visible)
            return
        scrollAnimation.stop()
        followingRow = index
        lines.cancelFlick()
        lines.forceLayout()
        const previous = lines.contentY
        const item = lines.itemAtIndex(index)
        let destination
        if (item) {
            destination = item.y
        } else {
            // Materialize distant rows to measure their position, then animate
            // from the original viewport instead of letting ListView snap there.
            lines.positionViewAtIndex(index, ListView.Beginning)
            lines.forceLayout()
            destination = lines.itemAtIndex(index)?.y ?? lines.contentY
            lines.contentY = previous
        }
        scrollAnimation.from = previous
        scrollAnimation.to = destination
        scrollAnimation.duration = settling ? 220 : 650
        scrollAnimation.restart()
    }

    function followCurrent() {
        if (following)
            scrollToRow(subtitles.activeRow)
    }

    function resumeFollow() {
        resumeDelay.stop()
        following = true
        followCurrent()
    }

    Timer {
        id: resumeDelay
        interval: 5000
        onTriggered: {
            if (lines.dragging || transcriptScrollBar.pressed) {
                restart()
                return
            }
            root.resumeFollow()
        }
    }

    NumberAnimation {
        id: scrollAnimation
        target: lines
        property: "contentY"
        duration: 650
        easing.type: Easing.InOutSine
        onFinished: {
            // Wrapped rows change ListView's size estimates as they appear.
            // Ease into the measured position if that shifted during the scroll.
            const item = lines.itemAtIndex(root.followingRow)
            if (root.following && (!item || Math.abs(lines.contentY - item.y) > 1))
                root.scrollToRow(root.followingRow, true)
        }
    }

    Connections {
        target: root.subtitles
        function onActiveRowChanged() { root.followCurrent() }
        function onTranscriptChanged() {
            scrollAnimation.stop()
            Qt.callLater(root.followCurrent)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        AppText { text: "Transcript"; font.weight: Font.DemiBold; Layout.fillWidth: true }

        AppText {
            visible: root.subtitles.loading
            text: "Loading subtitles…"
            color: Theme.mutedForeground
        }

        AppButton {
            visible: !root.subtitles.loading && lines.count === 0
            text: root.emptyAction
            variant: "outline"
            onClicked: root.addRequested()
        }

        AppText {
            visible: !root.subtitles.loading && lines.count === 0
            text: root.emptyHint
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.mutedForeground
        }

        ListView {
            id: lines
            objectName: "subtitleTranscript"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.subtitles.transcript
            boundsBehavior: Flickable.StopAtBounds
            onDraggingChanged: {
                if (dragging) root.pauseFollow()
                else root.noteActivity()
            }
            onHeightChanged: Qt.callLater(root.followCurrent)
            onWidthChanged: Qt.callLater(root.followCurrent)
            // Leave room for even the final cue to reach the top.
            footer: Item { width: lines.width; height: lines.height }
            ScrollBar.vertical: AppScrollBar {
                id: transcriptScrollBar
                onPressedChanged: {
                    if (pressed) root.pauseFollow()
                    else root.noteActivity()
                }
            }

            WheelHandler {
                target: null
                blocking: false
                onWheel: event => {
                    root.pauseFollow()
                    event.accepted = false
                }
            }

            Item {
                id: resumeOverlay
                parent: lines
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 12
                width: resumeFollowButton.implicitWidth
                height: resumeFollowButton.implicitHeight
                z: 2
                readonly property bool shown: !root.following && lines.count > 0
                opacity: shown ? 1 : 0
                visible: opacity > 0
                enabled: shown
                transform: Translate { y: resumeOverlay.shown ? 0 : -16
                    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
                Behavior on opacity { NumberAnimation { duration: 180 } }

                AppButton {
                    id: resumeFollowButton
                    objectName: "resumeTranscriptFollow"
                    text: "Resume follow"
                    variant: "outline"
                    small: true
                    onClicked: root.resumeFollow()
                }
            }

            delegate: Rectangle {
                id: cue
                required property var modelData
                required property int index
                readonly property bool playing: root.player.position >= modelData.start
                    && root.player.position < modelData.end
                width: lines.width
                height: Math.max(48, passage.implicitHeight)
                radius: Theme.radiusSmall
                color: playing ? Qt.tint(Theme.card, Qt.alpha(Theme.accent, 0.10))
                    : cueHover.hovered ? Theme.neutralHover : Theme.card
                Behavior on color { ColorAnimation { duration: 180 } }

                function seek() {
                    resumeDelay.stop()
                    root.following = true
                    root.scrollToRow(cue.index)
                    root.player.seek(cue.modelData.start)
                }

                HoverHandler { id: cueHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: eventPoint => {
                        const point = eventPoint.position
                        const buttonPoint = cue.mapToItem(timestamp, point.x, point.y)
                        if (timestamp.contains(buttonPoint))
                            return
                        const textPoint = cue.mapToItem(passage, point.x, point.y)
                        if (passage.contains(textPoint))
                            return
                        cue.seek()
                    }
                }

                AppButton {
                    id: timestamp
                    objectName: "transcriptTimestamp"
                    width: 78
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 6
                    anchors.topMargin: 8
                    text: root.player.formatTime(cue.modelData.start)
                    contentItem: AppText {
                        text: timestamp.text
                        color: cue.playing ? Theme.accent : Theme.mutedForeground
                        font.pixelSize: 12
                        font.features: ({ "tnum": 1 })
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    variant: "ghost"
                    small: true
                    Accessible.name: "Seek to " + text
                    onClicked: cue.seek()
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    width: 3
                    radius: 1.5
                    color: Theme.accent
                    opacity: cue.playing ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }

                TextArea {
                    id: passage
                    anchors.left: timestamp.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    padding: 12
                    leftPadding: 8
                    readOnly: true
                    selectByMouse: true
                    text: cue.modelData.text
                    textFormat: TextEdit.PlainText
                    wrapMode: TextEdit.Wrap
                    font.family: "Noto Sans KR"
                    font.pixelSize: 16
                    color: Theme.foreground
                    background: null
                    Accessible.name: "Subtitle text"

                    function wordAt(x, y) {
                        const position = passage.positionAt(x, y)
                        let start = position
                        let end = position
                        const word = /[\w\u1100-\u11ff\u3131-\u318e\uac00-\ud7a3]/
                        while (start > 0 && word.test(passage.text[start - 1])) start--
                        while (end < passage.text.length && word.test(passage.text[end])) end++
                        if (start === end
                                || !/[\u1100-\u11ff\u3131-\u318e\uac00-\ud7a3]/.test(passage.text.slice(start, end)))
                            return null
                        const first = passage.positionToRectangle(start)
                        const last = passage.positionToRectangle(end)
                        if (y < first.y || y >= last.y + last.height
                                || (y < first.y + first.height && x < first.x)
                                || (y >= last.y && x >= last.x))
                            return null
                        return { start: start, end: end }
                    }

                    FontMetrics {
                        id: passageMetrics
                        font: passage.font
                    }

                    Repeater {
                        model: {
                            const word = wordHover.word
                            if (!word || passage.width <= 0)
                                return []
                            const segments = []
                            let first = passage.positionToRectangle(word.start)
                            let previous = first
                            for (let position = word.start + 1; position <= word.end; position++) {
                                const next = passage.positionToRectangle(position)
                                const wraps = next.y !== previous.y
                                if (wraps || position === word.end) {
                                    const edge = wraps ? previous.x + passageMetrics.advanceWidth(
                                        passage.text.slice(position - 1, position)) : next.x
                                    segments.push({
                                        left: first.x,
                                        right: edge,
                                        y: Math.round(first.y + passageMetrics.ascent
                                                      + passageMetrics.underlinePosition + 2)
                                    })
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
                            x: modelData.left
                            y: modelData.y
                            width: Math.max(0, modelData.right - modelData.left)
                            height: 2
                            z: 1

                            ShapePath {
                                strokeColor: Theme.foreground
                                strokeWidth: 2
                                strokeStyle: ShapePath.DashLine
                                dashPattern: [1, 1]
                                capStyle: ShapePath.FlatCap
                                fillColor: "transparent"
                                startY: 1
                                PathLine { x: underline.width; y: 1 }
                            }
                        }
                    }

                    HoverHandler {
                        id: wordHover
                        readonly property var word: hovered
                            ? passage.wordAt(point.position.x, point.position.y) : null
                        cursorShape: Qt.PointingHandCursor
                    }

                    Keys.onReturnPressed: {
                        if (selectedText)
                            root.lookupRequested(text, selectionStart, selectionEnd)
                    }
                    TapHandler {
                        onSingleTapped: eventPoint => {
                            root.noteActivity()
                            const word = passage.wordAt(eventPoint.position.x, eventPoint.position.y)
                            if (!word) {
                                cue.seek()
                                return
                            }
                            passage.select(word.start, word.end)
                            root.lookupRequested(passage.text, word.start, word.end)
                        }
                    }
                }
            }
        }
    }
}
