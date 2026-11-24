import QtQuick
import QtQuick.Shapes
import QtQuick.Controls
import sori_core
import "../style"

Rectangle {
    id: root
    required property real videoId
    property Component headerComponent: null
    property string youtubeId: ""
    property string pendingYoutubeId: ""
    property var renderHost: null
    property string text: ""
    property real savedPosition: 0
    property bool restoring: true
    property real pendingId: 0
    property real pendingPosition: 0
    signal lookupRequested(string text, int start, int end)
    signal saveFailed(string error)
    color: Theme.card
    radius: Theme.radius
    border.color: Theme.border

    function flush() {
        saveDelay.stop()
        if (pendingId || pendingYoutubeId) {
            const error = pendingYoutubeId ? Library.saveYoutubeTranscriptPosition(pendingYoutubeId, pendingPosition).error
                : Library.saveTranscriptPosition(pendingId, pendingPosition).error
            pendingYoutubeId = ""
            pendingId = 0
            if (error) saveFailed(error)
        }
    }
    function restore() {
        if (!visible || viewport.height <= 0) return
        viewport.contentY = savedPosition * Math.max(0, viewport.contentHeight - viewport.height)
        restoring = false
    }
    function prepareText() {
        if (renderHost)
            renderHost.setReadingLineHeight(passage.textDocument, Theme.transcriptLineHeight)
        Qt.callLater(restore)
    }
    onRenderHostChanged: Qt.callLater(prepareText)
    onTextChanged: {
        flush()
        restoring = true
        Qt.callLater(prepareText)
    }
    onYoutubeIdChanged: { flush(); restoring = true; Qt.callLater(restore) }
    onVideoIdChanged: {
        flush()
        restoring = true
        Qt.callLater(restore)
    }
    onVisibleChanged: {
        if (visible && restoring) Qt.callLater(restore)
        else if (!visible) flush()
    }
    Component.onDestruction: flush()
    Timer { id: saveDelay; interval: 500; onTriggered: root.flush() }

    Loader {
        id: header
        x: Theme.readerPadding
        y: 16
        width: parent.width - 2 * Theme.readerPadding
        sourceComponent: root.headerComponent
        visible: status === Loader.Ready
    }

    Flickable {
        id: viewport
        objectName: "untimedTranscriptViewport"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: header.visible ? header.bottom : parent.top
        anchors.leftMargin: Theme.readerPadding
        anchors.rightMargin: Theme.readerPadding
        anchors.bottomMargin: Theme.readerPadding
        anchors.topMargin: header.visible ? 12 : Theme.readerPadding
        clip: true
        contentWidth: width
        contentHeight: passage.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        onHeightChanged: if (root.restoring) Qt.callLater(root.restore)
        onContentYChanged: {
            if (!root.restoring && root.visible && root.text) {
                root.pendingId = root.videoId
                root.pendingYoutubeId = root.youtubeId
                root.pendingPosition = Math.max(0, Math.min(1, contentY / Math.max(1, contentHeight - height)))
                saveDelay.restart()
            }
        }
        ScrollBar.vertical: AppScrollBar { }
        TextArea {
            id: passage
            objectName: "untimedTranscriptText"
            width: viewport.width
            text: root.text
            textFormat: TextEdit.PlainText
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            padding: 0
            font.family: "Noto Sans KR"
            font.pixelSize: Theme.readerTextSize
            color: Theme.foreground
            background: null
            Accessible.name: "Untimed transcript"
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
                                              + passageMetrics.underlinePosition + 4)
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
                cursorShape: word ? Qt.PointingHandCursor : Qt.IBeamCursor
            }

            function lookupSelection() {
                if (/[가-힣ㄱ-ㆎᄀ-ᇿ]/.test(selectedText))
                    root.lookupRequested(text, selectionStart, selectionEnd)
            }
            Keys.onReturnPressed: lookupSelection()
            TapHandler {
                onSingleTapped: eventPoint => {
                    const word = passage.wordAt(eventPoint.position.x, eventPoint.position.y)
                    if (!word) return
                    passage.select(word.start, word.end)
                    passage.lookupSelection()
                }
            }
        }
    }
}
