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

    function followCurrent() {
        if (follow.checked && subtitles.activeRow >= 0)
            lines.positionViewAtIndex(subtitles.activeRow, ListView.Contain)
    }

    Connections {
        target: root.subtitles
        function onActiveRowChanged() { root.followCurrent() }
        function onTranscriptChanged() { Qt.callLater(root.followCurrent) }
    }

    RowLayout {
        Layout.fillWidth: true
        AppText { text: "Transcript"; font.weight: Font.DemiBold; Layout.fillWidth: true }
        CheckBox {
            id: follow
            text: "Follow playback"
            checked: true
            onToggled: root.followCurrent()
        }
    }

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
        onMovementStarted: follow.checked = false
        onHeightChanged: Qt.callLater(root.followCurrent)
        ScrollBar.vertical: AppScrollBar { }

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
                onClicked: root.player.seek(cue.modelData.start)
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
