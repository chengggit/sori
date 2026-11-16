import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sori_qt_playback
import "../style"
import "../components"

Item {
    id: root

    required property bool active
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

    function selectAt(position) {
        const range = wordRanges.find(range => position >= range.start && position < range.end)
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
        Qt.callLater(restoreProgress)
    }

    function leave() {
        flushProgress()
        tokenizeDelay.stop()
        analysis.close()
    }

    function analyzeSelection() {
        if (passage.selectedText.trim())
            analysis.lookup(passage.text, passage.selectionStart, passage.selectionEnd)
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

    WordAnalysis {
        id: analysis
        parent: Overlay.overlay
        sourceId: root.documentId
        x: parent.width - width - 20
        y: 76
    }

    Timer {
        id: saveProgress
        interval: 500
        onTriggered: root.flushProgress()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 10

        AppText {
            Layout.fillWidth: true
            visible: text !== ""
            color: Theme.destructive
            text: root.documentError || root.progressError
            wrapMode: Text.Wrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.card
            border.color: Theme.border
            radius: Theme.radiusLarge

            Flickable {
                id: viewport
                anchors.fill: parent
                anchors.margins: 2
                clip: true
                contentWidth: width
                contentHeight: passage.implicitHeight + 64
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
                    y: 32
                    width: Math.min(viewport.width - 64, 760)
                    padding: 0
                    readOnly: true
                    renderType: Theme.nativeText ? TextEdit.NativeRendering : TextEdit.QtRendering
                    selectByMouse: true
                    textFormat: TextEdit.PlainText
                    wrapMode: TextEdit.Wrap
                    color: Theme.foreground
                    font.family: "Noto Sans KR"
                    font.pixelSize: 19
                    background: null
                    Accessible.name: "Document text"

                    Keys.onReturnPressed: root.analyzeSelection()
                    TapHandler {
                        onSingleTapped: (eventPoint, button) => {
                            if (button === Qt.LeftButton) {
                                root.selectAt(passage.positionAt(eventPoint.position.x, eventPoint.position.y))
                            }
                        }
                    }
                }
            }
        }
    }
}
