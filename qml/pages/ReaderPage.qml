import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import sori_qt_playback
import "../style"
import "../components"

Item {
    id: root

    required property bool active
    required property var renderHost
    property real documentId: 0
    property string documentTitle: "Reader"
    property string documentError: ""
    property string progressError: ""
    property real restorePosition: 0
    property bool restoring: false
    property bool progressPending: false
    readonly property real scrollRange: Math.max(0, viewport.contentHeight - viewport.height)

    property var tokenWindow: null
    property var pendingWindow: null
    property int passageRequest: 0
    property bool tokenizationQueued: false
    property var wordRanges: []

    function rangeAt(position) {
        return wordRanges.find(range => position >= range.start && position < range.end) ?? null
    }

    function hoveredWord(x, y) {
        const position = passage.positionAt(x, y)
        const range = rangeAt(position) ?? rangeAt(position - 1)
        if (!range)
            return null
        const first = passage.positionToRectangle(range.start)
        const last = passage.positionToRectangle(range.end)
        if (y < first.y || y >= last.y + last.height
                || (y < first.y + first.height && x < first.x)
                || (y >= last.y && x >= last.x))
            return null
        return range
    }

    function queueTokenization() {
        if (active && !restoring && !documentError && passage.text)
            tokenizeDelay.restart()
    }

    function tokenizeVisiblePassage() {
        if (!active || !passage.text)
            return
        if (passageRequest) {
            tokenizationQueued = true
            return
        }
        tokenizationQueued = false
        const top = passage.positionAt(0, Math.max(0, viewport.contentY - passage.y))
        const bottom = passage.positionAt(passage.width,
            Math.min(passage.implicitHeight, viewport.contentY - passage.y + viewport.height))
        if (tokenWindow?.documentId === documentId && top >= tokenWindow.start && bottom <= tokenWindow.end)
            return

        let start = Math.max(0, top - 512)
        let end = Math.min(passage.text.length, start + 4096, bottom + 512)
        while (start > 0 && start < top && !/\s/.test(passage.text[start - 1]))
            start++
        while (end < passage.text.length && end > bottom && !/\s/.test(passage.text[end]))
            end--
        if (start >= end)
            return

        // JS, TextArea and the analyzer all use UTF-16 offsets.
        if (passage.text.charCodeAt(start) >= 0xdc00 && passage.text.charCodeAt(start) <= 0xdfff)
            start--
        if (passage.text.charCodeAt(end) >= 0xdc00 && passage.text.charCodeAt(end) <= 0xdfff)
            end--
        pendingWindow = { documentId: documentId, start: start, end: end }
        passageRequest = Analysis.tokenizePassage(passage.text.slice(start, end))
    }

    function selectAt(position, range) {
        range = range ?? rangeAt(position)
        if (range) {
            passage.select(range.start, range.end)
        } else {
            passage.cursorPosition = position
            passage.selectWord()
        }
        analyzeSelection()
    }

    function openDocument(id, title) {
        leave()
        const document = Library.readDocument(id)
        tokenWindow = null
        pendingWindow = null
        wordRanges = []
        restoring = true
        documentId = id
        documentTitle = title
        documentError = document.error || ""
        progressError = ""
        restorePosition = document.position ?? 0
        passage.text = document.content ?? ""
        renderHost.setReadingLineHeight(passage.textDocument, Theme.readerLineHeight)
        Qt.callLater(restoreProgress)
    }

    function leave() {
        flushProgress()
        tokenizeDelay.stop()
        analysis.close()
    }

    function dismissAnalysis() {
        const position = passage.positionAt(0, Math.max(0, viewport.contentY - passage.y))
        const offset = passage.positionToRectangle(position).y - viewport.contentY
        analysis.close()
        passage.deselect()
        Qt.callLater(() => keepTextPosition(position, offset))
    }

    function keepTextPosition(position, offset) {
        if (active && !restoring)
            viewport.contentY = Math.max(0, Math.min(scrollRange, passage.positionToRectangle(position).y - offset))
    }

    function analyzeSelection() {
        if (!passage.selectedText.trim())
            return
        const position = passage.selectionStart
        const offset = passage.positionToRectangle(position).y - viewport.contentY
        analysis.lookup(passage.text, position, passage.selectionEnd)
        Qt.callLater(() => keepTextPosition(position, offset))
    }

    function restoreProgress() {
        if (!root.active || !root.restoring)
            return
        viewport.contentY = root.restorePosition * root.scrollRange
        root.restoring = false
        queueTokenization()
    }

    function flushProgress() {
        if (!progressPending)
            return
        progressPending = false
        saveProgress.stop()
        if (root.documentId && !root.restoring)
            root.progressError = Library.saveReadingProgress(root.documentId,
                root.scrollRange ? Math.max(0, Math.min(1, viewport.contentY / root.scrollRange)) : 0)
    }

    onActiveChanged: if (active) Qt.callLater(restoreProgress)

    Timer {
        id: tokenizeDelay
        interval: 120
        onTriggered: root.tokenizeVisiblePassage()
    }

    Connections {
        target: Analysis
        function onPassageFinished(request, result) {
            if (request !== root.passageRequest)
                return
            root.passageRequest = 0
            const window = root.pendingWindow
            root.pendingWindow = null
            if (window && Array.isArray(result)) {
                root.tokenWindow = window
                root.wordRanges = result.map(range => ({
                    start: range.start + window.start,
                    end: range.end + window.start
                }))
            }
            if (root.tokenizationQueued)
                root.queueTokenization()
        }
    }

    ReaderAnalysis {
        id: analysis
        documentId: root.documentId
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: visible ? Math.min(Theme.readerAnalysisWidth, root.width * 0.45) : 0
        visible: opened
        onDismissRequested: root.dismissAnalysis()
    }

    Shortcut {
        enabled: root.active && analysis.opened && !analysis.editing
        sequence: "Escape"
        onActivated: root.dismissAnalysis()
    }

    Timer {
        id: saveProgress
        interval: 500
        onTriggered: root.flushProgress()
    }

    ColumnLayout {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: analysis.left
        spacing: 10

        AppText {
            Layout.fillWidth: true
            visible: text !== ""
            color: Theme.destructive
            text: root.documentError || root.progressError
            wrapMode: Text.Wrap
        }

        Flickable {
            id: viewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: passage.implicitHeight + 2 * Theme.readerPadding
            boundsBehavior: Flickable.StopAtBounds
            onWidthChanged: root.queueTokenization()
            onHeightChanged: root.queueTokenization()
            onContentYChanged: {
                root.queueTokenization()
                if (root.active && root.documentId && !root.restoring
                        && !root.documentError && !root.progressPending) {
                    root.progressPending = true
                    saveProgress.start()
                }
            }
            ScrollBar.vertical: ScrollBar {}

            TextArea {
                id: passage
                objectName: "readerText"
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.readerPadding
                width: Math.max(0, Math.min(viewport.width - 2 * Theme.readerPadding, Theme.readerTextWidth))
                padding: 0
                readOnly: true
                renderType: Theme.nativeText ? TextEdit.NativeRendering : TextEdit.QtRendering
                selectByMouse: true
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.Wrap
                color: Qt.alpha(Theme.foreground, 0.86)
                font.family: "Noto Sans KR"
                font.pixelSize: Theme.readerTextSize
                font.weight: Font.Light
                background: null
                Accessible.name: "Document text"

                Keys.onReturnPressed: root.analyzeSelection()

                FontMetrics {
                    id: readingMetrics
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
                                const edge = wraps ? previous.x + readingMetrics.advanceWidth(
                                    passage.text.slice(position - 1, position)) : next.x
                                segments.push({
                                    left: first.x,
                                    right: edge,
                                    y: Math.round(first.y + readingMetrics.ascent
                                                  + readingMetrics.underlinePosition
                                                  + Theme.readerUnderlineOffset)
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
                    readonly property var word: hovered && root.active
                        ? root.hoveredWord(point.position.x, point.position.y) : null
                    cursorShape: word ? Qt.PointingHandCursor : Qt.IBeamCursor
                }

                TapHandler {
                    onSingleTapped: (eventPoint, button) => {
                        if (button === Qt.LeftButton) {
                            const point = eventPoint.position
                            root.selectAt(passage.positionAt(point.x, point.y),
                                          root.hoveredWord(point.x, point.y))
                        }
                    }
                }
            }
        }
    }
}
