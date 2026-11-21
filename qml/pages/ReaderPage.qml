import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import sori_core
import "../style"
import "../components"

Item {
    id: root
    clip: true

    required property bool active
    required property var renderHost
    required property var pdfText
    property real documentId: 0
    property string documentTitle: "Reader"
    property string documentError: ""
    property string progressError: ""
    property string pdfPath: ""
    readonly property string pdfUrl: pdfPath ? renderHost.localUrl(pdfPath) : ""
    readonly property bool isPdf: pdfPath !== ""
    property bool bookMode: false
    readonly property int pdfPageIndex: bookMode ? bookReader.currentPage : pdfPageReader.currentPage
    readonly property int pdfPageCount: bookMode ? bookReader.pageCount : pdfPageReader.pageCount
    readonly property real pdfPosition: bookMode ? bookReader.position : pdfPageReader.position
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
        if (active && !isPdf && !restoring && !documentError && passage.text)
            tokenizeDelay.restart()
    }

    function tokenizeVisiblePassage() {
        if (!active || isPdf || !passage.text)
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

    function selectWord(range) {
        if (!range)
            return
        passage.select(range.start, range.end)
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
        pdfPath = document.pdfPath || ""
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
        if (root.isPdf) {
            analysis.close()
            return
        }
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
        if (root.isPdf
                || !/[\u1100-\u11ff\u3131-\u318e\ua960-\ua97c\uac00-\ud7a3\ud7b0-\ud7fb]/.test(passage.selectedText))
            return
        const position = passage.selectionStart
        const offset = passage.positionToRectangle(position).y - viewport.contentY
        analysis.lookup(passage.text, position, passage.selectionEnd)
        Qt.callLater(() => keepTextPosition(position, offset))
    }

    function currentPosition() {
        if (root.isPdf)
            return Math.max(0, Math.min(1, root.pdfPosition))
        return root.scrollRange
            ? Math.max(0, Math.min(1, viewport.contentY / root.scrollRange))
            : 0
    }

    function toggleBookMode() {
        if (!root.isPdf)
            return
        root.restorePosition = root.currentPosition()
        root.progressPending = true
        root.flushProgress()
        root.bookMode = !root.bookMode
        Qt.callLater(() => {
            if (root.bookMode)
                bookReader.restoreProgress()
            else
                pdfPageReader.restoreProgress()
        })
    }

    function restoreProgress() {
        if (!root.active || !root.restoring)
            return
        if (root.isPdf) {
            if (root.bookMode)
                bookReader.restoreProgress()
            else
                pdfPageReader.restoreProgress()
        } else {
            viewport.contentY = root.restorePosition * root.scrollRange
        }
        // Tokenization must be queued after the restore flag clears, otherwise
        // queueTokenization() refuses to run and the text stays unclickable.
        root.restoring = false
        if (!root.isPdf)
            queueTokenization()
    }

    function flushProgress() {
        if (!progressPending)
            return
        progressPending = false
        saveProgress.stop()
        if (root.documentId && !root.restoring)
            root.progressError = Library.saveReadingProgress(root.documentId,
                root.currentPosition())
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
        objectName: "readerAnalysisSidebar"
        documentId: root.documentId
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        animateEntrance: true
        width: Math.min(Theme.readerAnalysisWidth, root.width * 0.45)
        anchors.rightMargin: -(1 - revealProgress) * width
        visible: opened || revealProgress > 0
        onDismissRequested: root.dismissAnalysis()
    }

    Shortcut {
        enabled: root.active && analysis.opened
        sequence: "Escape"
        onActivated: {
            if (analysis.editing)
                analysis.closeSaveEditor()
            else
                root.dismissAnalysis()
        }
    }

    Shortcut {
        enabled: root.active && root.isPdf && root.bookMode && root.pdfPageIndex > 0
        sequence: "Left"
        onActivated: bookReader.previousPage()
    }

    Shortcut {
        enabled: root.active && root.isPdf && root.bookMode
            && root.pdfPageIndex < root.pdfPageCount - 1
        sequence: "Right"
        onActivated: bookReader.nextPage()
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

        RowLayout {
            Layout.fillWidth: true
            visible: root.isPdf
            spacing: 8

            AppButton {
                iconName: "arrow-left"
                variant: "outline"
                small: true
                visible: root.bookMode
                Accessible.name: "Previous page"
                enabled: root.pdfPageIndex > 0
                onClicked: bookReader.previousPage()
            }

            AppText {
                text: root.pdfPageCount > 0
                    ? "Page " + (root.pdfPageIndex + 1) + " / " + root.pdfPageCount
                    : "PDF"
                color: Theme.mutedForeground
                font.pixelSize: 12
            }

            AppButton {
                iconName: "arrow-left"
                rotation: 180
                variant: "outline"
                small: true
                visible: root.bookMode
                Accessible.name: "Next page"
                enabled: root.pdfPageCount > 0 && root.pdfPageIndex < root.pdfPageCount - 1
                onClicked: bookReader.nextPage()
            }

            Item {
                Layout.fillWidth: true
            }

            AppButton {
                text: root.bookMode ? "Scroll" : "Book"
                variant: "outline"
                small: true
                onClicked: root.toggleBookMode()
            }
        }

        AppText {
            Layout.fillWidth: true
            visible: text !== ""
            color: Theme.destructive
            text: root.documentError || root.progressError
            wrapMode: Text.Wrap
        }

        PdfPageReader {
            id: pdfPageReader
            objectName: "pdfPageReader"
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.isPdf && !root.bookMode
            pdfPath: root.pdfPath
            pdfUrl: root.pdfUrl
            pdfText: root.pdfText
            restorePosition: root.restorePosition
            onWordRequested: (text, start, end) => analysis.lookup(text, start, end)
            onPositionChanged: {
                if (root.active && root.documentId && !root.restoring
                        && !pdfPageReader.restoring && !root.progressPending) {
                    root.progressPending = true
                    saveProgress.start()
                }
            }
        }

        PdfBookReader {
            id: bookReader
            objectName: "pdfBookReader"
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.isPdf && root.bookMode
            pdfUrl: root.pdfUrl
            pdfText: root.pdfText
            restorePosition: root.restorePosition
            onWordRequested: (text, start, end) => analysis.lookup(text, start, end)
            onPositionChanged: {
                if (root.active && root.documentId && !root.restoring
                        && !root.progressPending) {
                    root.progressPending = true
                    saveProgress.start()
                }
            }
        }

        Flickable {
            id: viewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.isPdf
            clip: true
            contentWidth: width
            contentHeight: passage.implicitHeight + 2 * Theme.readerPadding
            boundsBehavior: Flickable.StopAtBounds
            onWidthChanged: root.queueTokenization()
            onHeightChanged: root.queueTokenization()
            onContentYChanged: {
                if (root.isPdf)
                    return
                root.queueTokenization()
                if (root.active && root.documentId && !root.restoring
                        && !root.documentError && !root.progressPending) {
                    root.progressPending = true
                    saveProgress.start()
                }
            }
            onDraggingChanged: if (dragging) wheelScroll.stop()

            NumberAnimation {
                id: wheelScroll
                target: viewport
                property: "contentY"
                duration: 180
                easing.type: Easing.OutCubic
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                target: null
                blocking: true
                onWheel: event => {
                    if (event.angleDelta.y === 0 && event.pixelDelta.y === 0) {
                        event.accepted = false
                        return
                    }
                    event.accepted = true
                    const precise = event.pixelDelta.y !== 0
                    // A wheel notch is 120 angle units. Scroll by distance,
                    // rather than a flick velocity that Qt caps and decelerates.
                    const distance = precise ? event.pixelDelta.y * 2 : event.angleDelta.y / 120 * 300
                    const previousTarget = wheelScroll.running ? wheelScroll.to : viewport.contentY
                    wheelScroll.stop()
                    viewport.cancelFlick()
                    const minimum = viewport.originY
                    const maximum = Math.max(minimum, minimum + viewport.contentHeight - viewport.height)
                    const destination = Math.max(minimum, Math.min(maximum,
                        (precise ? viewport.contentY : previousTarget) - distance))
                    if (precise) {
                        viewport.contentY = destination
                    } else {
                        wheelScroll.from = viewport.contentY
                        wheelScroll.to = destination
                        wheelScroll.restart()
                    }
                }
            }
            ScrollBar.vertical: AppScrollBar {
                onPressedChanged: if (pressed) wheelScroll.stop()
            }

            TextArea {
                id: passage
                objectName: "readerText"
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.readerPadding
                width: Math.max(0, Math.min(viewport.width - 2 * Theme.readerPadding, Theme.readerTextWidth))
                padding: 0
                readOnly: true
                renderType: TextEdit.QtRendering
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
                            root.selectWord(root.hoveredWord(point.x, point.y))
                        }
                    }
                }
            }
        }
    }
}
