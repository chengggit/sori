import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../style"

ColumnLayout {
    id: root
    required property var subtitles
    required property var player
    signal lookupRequested(string text, int start, int end)
    signal addRequested()
    spacing: 8

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

    AppText { text: "Transcript"; font.weight: Font.DemiBold; Layout.fillWidth: true }

    AppText {
        visible: root.subtitles.loading
        text: "Loading subtitles…"
        color: Theme.mutedForeground
    }

    AppButton {
        visible: !root.subtitles.loading && lines.count === 0
        text: "Add subtitle files"
        variant: "outline"
        onClicked: root.addRequested()
    }

    AppText {
        visible: !root.subtitles.loading && lines.count === 0
        text: "Select a primary text track in CC or add an SRT or VTT file."
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
            height: Math.max(40, passage.implicitHeight + 16)
            radius: Theme.radiusSmall
            color: playing ? Theme.neutralHover : "transparent"

            AppButton {
                id: timestamp
                anchors.left: parent.left
                anchors.top: parent.top
                text: root.player.formatTime(cue.modelData.start)
                variant: "ghost"
                small: true
                Accessible.name: "Seek to " + text
                onClicked: {
                    resumeDelay.stop()
                    root.following = true
                    root.scrollToRow(cue.index)
                    root.player.seek(cue.modelData.start)
                }
            }

            TextArea {
                id: passage
                anchors.left: timestamp.right
                anchors.right: parent.right
                anchors.top: parent.top
                padding: 8
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
                Keys.onReturnPressed: {
                    if (selectedText)
                        root.lookupRequested(text, selectionStart, selectionEnd)
                }
                TapHandler {
                    onSingleTapped: eventPoint => {
                        root.noteActivity()
                        const position = passage.positionAt(eventPoint.position.x, eventPoint.position.y)
                        let start = position
                        let end = position
                        const word = /[\w\u1100-\u11ff\u3131-\u318e\uac00-\ud7a3]/
                        while (start > 0 && word.test(passage.text[start - 1])) start--
                        while (end < passage.text.length && word.test(passage.text[end])) end++
                        if (/[\u1100-\u11ff\u3131-\u318e\uac00-\ud7a3]/.test(passage.text.slice(start, end))) {
                            passage.select(start, end)
                            root.lookupRequested(passage.text, start, end)
                        }
                    }
                }
            }
        }
    }
}
